//
//  RefreshLiveActivityRunner.swift
//  cue / Shared
//

@preconcurrency import ActivityKit
import Foundation

/// 「라이브 새로고침」 인텐트의 실제 동작 — **지금 살아있는 라이브만** 새로 게시한다.
///
/// 인텐트에서 분리한 이유는 `AppIntent` 타입 안에 로직을 두면 테스트에서 인텐트를 직접
/// 실행해야 하는데 그게 시스템에 묶여 있기 때문이다.
///
/// **`@MainActor`인 이유** — 저장소·서비스 조립이 메인 액터를 전제한다.
/// `LiveActivityIntent`의 `perform()`은 앱 프로세스에서 실행되므로 그대로 쓸 수 있다.
@MainActor
enum RefreshLiveActivityRunner {

    /// 살아있는 라이브를 끝내고 새로 게시해 8시간 한도를 다시 시작한다.
    ///
    /// **기준은 "지금 화면에 살아있는가"** 다. 예전엔 "켠 적 있고 앱에서 끄지 않았다"는
    /// 기록을 썼는데, 잠금화면에서 밀어 치운 라이브는 앱을 거치지 않아 기록에 남았다 —
    /// 실제 증상: 밤에 할일만 켜뒀는데 08:00 자동화 뒤 일정이 떠 있었다(2026-10-01 보고).
    /// 시스템이 이미 끝낸(`.ended`) 카드도 되살리지 않는다 — 꺼지기 전에 자동화가 돌아야 한다.
    ///
    /// **제자리 update가 아니라 끝낸 뒤 새로** — update는 8시간 타이머를 리셋하지 않고,
    /// 종류마다 전부 끝낸 뒤 하나만 게시해야 같은 종류가 겹치지 않는다. 살아있지 않은 종류는
    /// 잠금화면에 남은 잔상까지 끝낸다.
    ///
    /// 실패는 조용히 삼킨다 — 자동화 경로라 사용자에게 보여줄 화면이 없다.
    static func run(
        settingsRepository: any AppSettingsRepository = UserDefaultsAppSettingsRepository(),
        memoRepository: any MemoRepository = UserDefaultsMemoRepository(),
        remindersRepository: any RemindersRepository = EventKitRemindersRepository(),
        eventsRepository: any EventsRepository = EventKitEventsRepository(),
        service: any LiveActivityService = ActivityKitLiveActivityService(),
        isPremium: Bool = SharedAppGroup.isPremium,
        alive: Set<LiveActivityKind> = aliveKinds(),
        now: Date = .now
    ) async {
        // 프리미엄 전용 — 무료 사용자는 하루 한 번 한도(`ConsumeLiveActivationUseCase`)를
        // 쓰는데, 자동화를 허용하면 그 한도를 우회하는 뒷문이 된다. 끝내는 것도 하지 않는다 —
        // 무료 사용자가 수동으로 켠 라이브를 단축어가 지우면 안 된다.
        guard isPremium else { return }

        let settings = await settingsRepository.fetch()

        // 설정의 표시 순서대로 재게시 — 정렬 자체는 각 게시에 실리는 relevanceScore가
        // 정하고, 순회는 게시 시점(동점의 보조 기준)까지 화면과 맞추기 위해 같은 순서로
        // 돈다(항상 표시 경로 `startAlwaysOnActivities`와 동일).
        for kind in settings.resolvedLiveOrder {
            guard alive.contains(kind) else {
                await clear(kind, service: service)
                continue
            }
            switch kind {
            case .memo:
                await republishMemo(memoRepository: memoRepository, service: service)
            case .reminder:
                await republishReminder(
                    settings: settings, repository: remindersRepository,
                    eventsRepository: eventsRepository, service: service, now: now
                )
            case .schedule:
                await republishSchedule(
                    settings: settings, eventsRepository: eventsRepository,
                    service: service, now: now
                )
            case .focus:
                break
            }
        }
    }

    /// 시스템에 살아있는(`.active`·`.stale`) 라이브 종류 — 테스트 불가능한 ActivityKit 글루.
    /// 생존 판단 규칙 자체는 `LiveActivityHandlePicker`에 있고 거기서 검증된다.
    nonisolated static func aliveKinds() -> Set<LiveActivityKind> {
        var kinds = Set<LiveActivityKind>()
        if Activity<MemoLiveActivityAttributes>.liveActivity != nil { kinds.insert(.memo) }
        if Activity<ReminderLiveActivityAttributes>.liveActivity != nil { kinds.insert(.reminder) }
        if Activity<ScheduleLiveActivityAttributes>.liveActivity != nil { kinds.insert(.schedule) }
        return kinds
    }

    /// 살아있지 않은 종류의 잔상(시스템이 끝냈지만 잠금화면에 남은 카드)을 끝낸다.
    private static func clear(_ kind: LiveActivityKind, service: any LiveActivityService) async {
        switch kind {
        case .memo: await service.endMemo()
        case .reminder: await service.endReminder()
        case .schedule: await service.endSchedule()
        case .focus: break
        }
    }

    // MARK: - 메모

    private static func republishMemo(
        memoRepository: any MemoRepository,
        service: any LiveActivityService
    ) async {
        let memo = await memoRepository.fetch()
        // 빈 메모는 use case가 throw한다 — 시도 자체를 막아 의도를 분명히 한다.
        guard RefreshLiveActivityDecision.canPublishMemo(memo) else { return }
        // 내용을 확인한 뒤에야 끝낸다 — 실패한 새로고침이 살아있는 카드를 지우면 안 된다.
        await service.endMemo()
        try? await StartMemoLiveActivityUseCase(service: service)(memo)
    }

    // MARK: - 할일

    /// 설정에 저장된 **할일 범위**로 스냅샷을 만들어 게시한다.
    ///
    /// 화면의 현재 선택이 아니라 「항상 표시」 범위를 쓴다 — 자동화는 화면과 무관하게 돌고,
    /// 사용자가 그 설정에서 "라이브에 뭘 띄울지"를 이미 골랐기 때문이다.
    private static func republishReminder(
        settings: AppSettings,
        repository: any RemindersRepository,
        eventsRepository: any EventsRepository,
        service: any LiveActivityService,
        now: Date
    ) async {
        guard await repository.currentAccess() == .granted else { return }
        guard let lists = try? await repository.fetchLists(),
              let all = try? await repository.fetchReminders() else { return }

        let scope = RefreshLiveActivitySelection.reminderScope(
            scopeID: settings.liveAlwaysOnReminderScopeID, lists: lists
        )
        let visible = RefreshLiveActivitySelection.visibleReminders(
            all, hiddenListIDs: settings.hiddenReminderListIDs
        )
        let items = RefreshLiveActivitySelection.matching(visible, scope: scope, now: now)
        // 빈 목록으로 게시하면 잠금화면에 빈 카드가 남는다 — 아무것도 안 하는 편이 낫다.
        guard !items.isEmpty else { return }

        let colors = Dictionary(uniqueKeysWithValues: lists.compactMap { list in
            list.colorHex.map { (list.id, $0) }
        })
        let week = await weekEvents(eventsRepository, settings: settings, now: now)
        // 재료를 다 모은 뒤에 끝낸다 — 끝내고 새로 켜기까지 카드가 비는 틈을 줄인다.
        await service.endReminder()
        try? await StartReminderLiveActivityUseCase(service: service)(
            listTitle: RefreshLiveActivitySelection.title(for: scope, lists: lists),
            reminders: items,
            listColors: colors,
            weekEvents: week,
            now: now
        )
    }

    // MARK: - 일정

    private static func republishSchedule(
        settings: AppSettings,
        eventsRepository: any EventsRepository,
        service: any LiveActivityService,
        now: Date
    ) async {
        guard await eventsRepository.currentAccess() == .granted else { return }
        // 화면의 첫 페이지와 같은 폭(30일)을 읽는다 — use case가 총량을 다시 자르므로
        // 여기서는 "다가오는 일정이 충분히 들어오는" 범위면 된다.
        let from = Calendar.current.startOfDay(for: now)
        guard let to = Calendar.current.date(byAdding: .day, value: 30, to: from),
              let fetched = try? await eventsRepository.fetchEvents(from: from, to: to)
        else { return }

        let visible = RefreshLiveActivitySelection.visibleEvents(
            fetched, hiddenCalendarIDs: settings.hiddenCalendarIDs
        )
        // 다가오는 일정이 없으면 use case가 게시하지 않는다 — 끝내기 전에 먼저 확인한다.
        guard !StartScheduleLiveActivityUseCase.groupIntoDays(visible, now: now).isEmpty else { return }
        let week = await weekEvents(eventsRepository, settings: settings, now: now)
        await service.endSchedule()
        try? await StartScheduleLiveActivityUseCase(service: service)(
            events: visible,
            weekEvents: week,
            now: now
        )
    }

    // MARK: - 공용

    /// Dynamic Island 주간 스트립의 날짜별 점 — 할일·일정 라이브가 같이 쓴다.
    /// 실패하면 빈 배열(점 없음)로 진행한다 — 점이 없다고 라이브를 포기할 이유는 없다.
    private static func weekEvents(
        _ repository: any EventsRepository,
        settings: AppSettings,
        now: Date
    ) async -> [CalendarEvent] {
        guard let week = WeekEventDotsBuilder.weekRange(for: now),
              let fetched = try? await repository.fetchEvents(from: week.start, to: week.end)
        else { return [] }
        return RefreshLiveActivitySelection.visibleEvents(
            fetched, hiddenCalendarIDs: settings.hiddenCalendarIDs
        )
    }
}
