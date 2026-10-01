//
//  RefreshLiveActivityRunnerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 단축어 「라이브 새로고침」 — **지금 살아있는 카드만** 새로 게시한다.
///
/// 실제 증상(2026-10-01 보고): 밤에 할일 라이브만 켜두고 08:00 자동화를 걸었더니, 아침에
/// 할일 대신 **일정** 라이브가 떠 있었다. 되살릴 근거가 "예전에 켠 적 있다"는 기록이라,
/// 잠금화면에서 밀어 치운 일정도 기록에 남아 함께 되살아났다. 기준을 "지금 화면에 살아있는가"
/// 로 바꾸고, 새 카드를 **먼저** 게시한 뒤 옛 카드를 끝낸다(제자리 update는 8시간 타이머를
/// 리셋하지 않고, 먼저 끝내면 백그라운드 게시가 막혔을 때 카드가 사라진다 — 같은 날 재보고).
@MainActor
struct RefreshLiveActivityRunnerTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 살아있지 않은 종류는 되살리지 않고, 잠금화면에 남은 잔상까지 끝낸다 — 오늘 아침 버그.
    @Test func doesNotRevivePastKindsAndClearsTheirLeftovers() async {
        let service = OrderRecordingLiveActivityService()

        await run(alive: [.reminder], service: service)

        let calls = await service.calls
        #expect(!calls.contains("startSchedule"))
        #expect(!calls.contains("startMemo"))
        #expect(calls.contains("endSchedule"))
        #expect(calls.contains("endMemo"))
    }

    /// 살아있는 종류는 **끝내지 않고** 교체를 예약한 뒤 새로 게시한다 — 옛 카드는 새 게시가
    /// 성공해야 서비스가 끝낸다. 먼저 끝내면 게시가 막혔을 때 카드가 그냥 사라진다.
    @Test func aliveKindIsRenewedWithoutEndingFirst() async {
        let service = OrderRecordingLiveActivityService()

        await run(alive: [.reminder], service: service)

        #expect(await service.calls(of: "reminder") == ["prepareRenewal(reminder)", "startReminder"])
    }

    /// 셋 다 살아있으면 셋 다 새로 게시한다 — "종류당 1개"지 "전체 1개"가 아니다.
    @Test func everyAliveKindIsRenewedOncePerKind() async {
        let service = OrderRecordingLiveActivityService()

        await run(alive: [.memo, .reminder, .schedule], service: service)

        #expect(await service.calls(of: "memo") == ["prepareRenewal(memo)", "startMemo"])
        #expect(await service.calls(of: "reminder") == ["prepareRenewal(reminder)", "startReminder"])
        #expect(await service.calls(of: "schedule") == ["prepareRenewal(schedule)", "startSchedule"])
    }

    /// 설정의 표시 순서대로 게시한다 — 잠금화면 정렬의 동점 보조 기준(게시 시점)까지 맞춘다.
    @Test func republishesInTheUsersLiveOrder() async {
        let service = OrderRecordingLiveActivityService()
        var settings = AppSettings.default
        settings.liveAlwaysOnOrder = [.schedule, .memo, .reminder]

        await run(alive: [.memo, .reminder, .schedule], settings: settings, service: service)

        let starts = await service.calls.filter { $0.hasPrefix("start") }
        #expect(starts == ["startSchedule", "startMemo", "startReminder"])
    }

    /// 새로 만들 내용이 없으면 살아있는 카드를 건드리지 않는다 — 실패한 새로고침이 카드를 지우면 안 된다.
    @Test func aliveKindWithNothingToPublishIsLeftAsIs() async {
        let service = OrderRecordingLiveActivityService()

        await run(alive: [.reminder], reminders: [], service: service)

        #expect(await service.calls(of: "reminder").isEmpty)
    }

    /// 무료 사용자는 아무것도 건드리지 않는다 — 수동으로 켠 라이브를 단축어가 지우면 안 된다.
    @Test func freeUserIsLeftUntouched() async {
        let service = OrderRecordingLiveActivityService()

        await run(alive: [.reminder], isPremium: false, service: service)

        #expect(await service.calls.isEmpty)
    }

    // MARK: - 종류 하나만 (단축어 동작을 종류별로 나눠 실행)

    /// 종류를 지정하면 그 종류만 다룬다 — 백그라운드 게시 권한이 실행 한 번에 하나로 보여,
    /// 자동화가 종류마다 따로 실행한다. 다른 종류를 건드리면 앞 실행이 켠 카드를 지운다.
    @Test func singleKindRunTouchesOnlyThatKind() async {
        let service = OrderRecordingLiveActivityService()

        await run(kind: .memo, alive: [.memo, .reminder, .schedule], service: service)

        #expect(await service.calls == ["prepareRenewal(memo)", "startMemo"])
    }

    /// 종류를 직접 고른 실행은 꺼져 있어도 켠다 — 고른 것 자체가 "띄워라"는 뜻이다.
    /// 남아 있던 잔상은 교체 대상으로 잡혀 새 카드가 뜬 뒤 정리된다.
    @Test func singleKindRunPublishesEvenWhenOff() async {
        let service = OrderRecordingLiveActivityService()

        await run(kind: .schedule, alive: [.memo], service: service)

        #expect(await service.calls == ["prepareRenewal(schedule)", "startSchedule"])
    }

    // MARK: - Helpers

    private func run(
        kind: LiveActivityKind? = nil,
        alive: Set<LiveActivityKind>,
        reminders: [Reminder]? = nil,
        settings: AppSettings = .default,
        isPremium: Bool = true,
        service: OrderRecordingLiveActivityService
    ) async {
        let event = CalendarEvent(
            id: "E1", title: "회의",
            startDate: now.addingTimeInterval(3600), endDate: now.addingTimeInterval(7200),
            isAllDay: false, calendarColorHex: nil, isReadOnly: false, calendarID: "C1"
        )
        await RefreshLiveActivityRunner.run(
            kind: kind,
            settingsRepository: InMemoryAppSettingsRepository(storage: settings),
            memoRepository: InMemoryMemoRepository(memo: Memo(text: "회의 준비", colorHex: "#000000")),
            remindersRepository: InMemoryRemindersRepository(
                lists: [ReminderList(id: "L1", title: "장보기", colorHex: nil)],
                reminders: reminders ?? [Reminder(id: "R1", title: "우유", isCompleted: false, listID: "L1")]
            ),
            eventsRepository: InMemoryEventsRepository(events: [event]),
            service: service,
            isPremium: isPremium,
            alive: alive,
            now: now
        )
    }
}

/// 호출 순서를 이름으로 기록하는 대역 — "교체 예약 → 새로 게시" 순서를 검증한다.
private final actor OrderRecordingLiveActivityService: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var calls: [String] = []

    /// 한 종류에 대한 호출만 — 이름에 종류가 들어간 것(대소문자 무시).
    func calls(of kind: String) -> [String] {
        calls.filter { $0.lowercased().contains(kind) }
    }

    func prepareRenewal(_ kind: LiveActivityKind) async { calls.append("prepareRenewal(\(kind.rawValue))") }

    func startReminder(
        listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int,
        weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?, isSample: Bool
    ) async throws { calls.append("startReminder") }
    func endReminder() async { calls.append("endReminder") }

    func startSchedule(
        days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots],
        showsCalendarOverride: Bool?, isSample: Bool
    ) async throws { calls.append("startSchedule") }
    func endSchedule() async { calls.append("endSchedule") }

    func startMemo(text: String, colorHex: String, textColorHex: String) async throws { calls.append("startMemo") }
    func endMemo() async { calls.append("endMemo") }

    // 동기화·레이아웃·예시 정리는 이 검증의 관심 밖이라 기록하지 않는다.
    func endSamples() async {}
    func sync() async {}
    func refreshLayout() async {}
}
