//
//  RefreshLiveActivityRunner.swift
//  cue / Shared
//

import Foundation

/// 「라이브 새로고침」 인텐트의 실제 동작 — 꺼진 라이브를 조건에 맞으면 다시 게시한다.
///
/// 인텐트에서 분리한 이유는 `AppIntent` 타입 안에 로직을 두면 테스트에서 인텐트를 직접
/// 실행해야 하는데 그게 시스템에 묶여 있기 때문이다.
///
/// **`@MainActor`인 이유** — 저장소·서비스 조립이 메인 액터를 전제한다.
/// `LiveActivityIntent`의 `perform()`은 앱 프로세스에서 실행되므로 그대로 쓸 수 있다.
@MainActor
enum RefreshLiveActivityRunner {

    /// 사용자가 켜둔 채로 둔 라이브를 다시 게시한다.
    ///
    /// 실패는 조용히 삼킨다 — 자동화 경로라 사용자에게 보여줄 화면이 없고, 다음 자동화가
    /// 8시간 뒤 다시 시도한다.
    static func run(
        settingsRepository: any AppSettingsRepository = UserDefaultsAppSettingsRepository(),
        memoRepository: any MemoRepository = UserDefaultsMemoRepository(),
        remindersRepository: any RemindersRepository = EventKitRemindersRepository(),
        eventsRepository: any EventsRepository = EventKitEventsRepository(),
        service: any LiveActivityService = ActivityKitLiveActivityService(),
        isPremium: Bool = SharedAppGroup.isPremium,
        wanted: Set<LiveActivityKind> = LiveActivityIntentRecord.wanted(),
        now: Date = .now
    ) async {
        guard isPremium, !wanted.isEmpty else { return }

        // 시스템에 살아있는 라이브 핸들을 먼저 재포착한다 — 앱이 백그라운드에서 깨어난
        // 직후라 서비스 내부 핸들이 비어 있다. 이게 없으면 이미 떠 있는 라이브를 못 보고
        // 매번 새로 게시해 8시간 타이머가 불필요하게 리셋된다.
        await service.sync()

        let settings = await settingsRepository.fetch()

        // 되살릴지 말지는 종류별로 `RefreshLiveActivityDecision`이 정한다 — 프리미엄·사용자
        // 의사 판단을 한곳에 모아 두어야 규칙이 갈라지지 않는다.
        let allows = { (kind: LiveActivityKind) in
            RefreshLiveActivityDecision.shouldRepublish(
                isPremium: isPremium, kind: kind, wanted: wanted
            )
        }
        if allows(.memo) {
            await republishMemo(memoRepository: memoRepository, service: service)
        }
        if allows(.reminder) {
            await republishReminder(
                settings: settings, repository: remindersRepository,
                eventsRepository: eventsRepository, service: service, now: now
            )
        }
        if allows(.schedule) {
            await republishSchedule(
                settings: settings, eventsRepository: eventsRepository,
                service: service, now: now
            )
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
        try? await StartReminderLiveActivityUseCase(service: service)(
            listTitle: RefreshLiveActivitySelection.title(for: scope, lists: lists),
            reminders: items,
            listColors: colors,
            weekEvents: await weekEvents(eventsRepository, settings: settings, now: now),
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
        // 다가오는 일정이 없으면 use case가 false를 돌려주고 게시하지 않는다.
        try? await StartScheduleLiveActivityUseCase(service: service)(
            events: visible,
            weekEvents: await weekEvents(eventsRepository, settings: settings, now: now),
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
