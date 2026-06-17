//
//  LiveActivityUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct LiveActivityUseCaseTests {

    // MARK: - StartReminder — cap / remaining / mapping

    @Test func startReminderCapsItemsAtStorageLimitAndComputesRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...25).map { reminder(id: "r\($0)", title: "할일 \($0)") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘",
            reminders: reminders,
            listColors: [:]
        )

        let calls = await service.startReminderCalls
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.listTitle == "오늘")
        // 표시는 6개지만 backfill용으로 20개까지 싣는다.
        #expect(call.items.count == 20)
        #expect(call.items.first?.id == "r1")
        #expect(call.items.last?.id == "r20")
        #expect(call.remaining == 5)
    }

    @Test func startReminderUnderStorageLimitKeepsAllForBackfill() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...8).map { reminder(id: "r\($0)", title: "할일 \($0)") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘",
            reminders: reminders,
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        // 8개 전부 싣어야 체크로 하나 빠져도 위젯 6칸이 안 빈다.
        #expect(call.items.count == 8)
        #expect(call.remaining == 0)
    }

    @Test func startReminderMapsEachItemListColor() async throws {
        let service = RecordingLiveActivityService()
        let reminders = [
            reminder(id: "r1", title: "회사 일", listID: "work"),
            reminder(id: "r2", title: "개인 일", listID: "personal"),
            reminder(id: "r3", title: "색 없는 리스트", listID: "nocolor"),
        ]

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "전체",
            reminders: reminders,
            listColors: ["work": "#FF9500", "personal": "#34C759"]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.map(\.colorHex) == ["#FF9500", "#34C759", nil])
    }

    @Test func startReminderWithExactCapHasZeroRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...20).map { reminder(id: "r\($0)", title: "X") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "전체",
            reminders: reminders,
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.count == 20)
        #expect(call.remaining == 0)
    }

    @Test func startReminderEmptyListPassesEmptyItems() async throws {
        let service = RecordingLiveActivityService()

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "비어있음",
            reminders: [],
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.isEmpty)
        #expect(call.remaining == 0)
    }

    // MARK: - ContentState.removingItem — LA에서 완료 항목 제거

    @Test func removingItemDropsMatchingItemAndLowersCount() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [
                LiveReminderItem(id: "r1", title: "A", colorHex: nil),
                LiveReminderItem(id: "r2", title: "B", colorHex: nil),
                LiveReminderItem(id: "r3", title: "C", colorHex: nil),
            ],
            remaining: 2
        )

        let next = state.removingItem(id: "r2")

        #expect(next.items.map(\.id) == ["r1", "r3"])
        #expect(next.remaining == 2)
        // 표시 카운트(items + remaining)는 5 → 4로 1 감소.
        #expect(next.items.count + next.remaining == 4)
    }

    @Test func removingUnknownItemLeavesStateUnchanged() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [LiveReminderItem(id: "r1", title: "A", colorHex: nil)],
            remaining: 0
        )

        let next = state.removingItem(id: "nope")

        #expect(next.items.map(\.id) == ["r1"])
        #expect(next.remaining == 0)
    }

    // MARK: - StartSchedule — 날짜 그룹핑 + 라벨 + 종일 정렬

    @Test func startScheduleGroupsByDayWithRelativeLabels() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let baseDay = cal.startOfDay(for: .now)
        // now를 그날 06:00로 고정하고 이벤트는 09:00~ → 실제 시계와 무관하게 지난-이벤트 필터에 안 걸림.
        let now = baseDay.addingTimeInterval(6 * 3600)
        let day = { (offset: Int) in cal.date(byAdding: .day, value: offset, to: baseDay)! }

        let events = [
            event(id: "t1", title: "오늘일정", start: day(0).addingTimeInterval(9 * 3600), end: day(0).addingTimeInterval(10 * 3600), colorHex: "#FF0000"),
            event(id: "m1", title: "내일일정", start: day(1).addingTimeInterval(9 * 3600), end: day(1).addingTimeInterval(10 * 3600), colorHex: nil),
            event(id: "mo1", title: "모레일정", start: day(2).addingTimeInterval(9 * 3600), end: day(2).addingTimeInterval(10 * 3600), colorHex: nil),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: now)

        let days = try #require(await service.startScheduleCalls.first)
        #expect(days.map(\.label) == ["오늘", "내일", "모레"])
        #expect(days.map { $0.events.map(\.id) } == [["t1"], ["m1"], ["mo1"]])
        #expect(days.first?.events.first?.calendarColorHex == "#FF0000")
    }

    @Test func startScheduleLabelsFarDayAsDateNotRelative() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let day3 = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: .now))!
        let events = [event(id: "f1", title: "먼일정", start: day3.addingTimeInterval(3600), end: day3.addingTimeInterval(7200), colorHex: nil)]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: .now)

        let label = try #require(await service.startScheduleCalls.first?.first?.label)
        // 3일 뒤는 오늘/내일/모레가 아니라 날짜 형식("4/10 (수)" 류).
        #expect(!["오늘", "내일", "모레"].contains(label))
        #expect(label.contains("/"))
    }

    @Test func startScheduleCapsTotalEventsForContentStateLimit() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // 5일 × 6개 = 30개 — 4KB 한도 위험. use case가 총량을 잘라야 한다.
        let events = (0..<5).flatMap { dayOffset in
            (0..<6).map { i in
                let day = cal.date(byAdding: .day, value: dayOffset, to: today)!
                return event(
                    id: "d\(dayOffset)-e\(i)", title: "일정",
                    start: day.addingTimeInterval(Double(3600 * (i + 1))),
                    end: day.addingTimeInterval(Double(3600 * (i + 2))),
                    colorHex: nil
                )
            }
        }

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: .now)

        let days = try #require(await service.startScheduleCalls.first)
        let total = days.reduce(0) { $0 + $1.events.count }
        #expect(total <= StartScheduleLiveActivityUseCase.maxTotalEvents)
    }

    @Test func startScheduleExcludesPastDaysEntirely() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let now = cal.startOfDay(for: .now).addingTimeInterval(10 * 3600)  // 오늘 10:00
        let yStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now))!

        // EventKit straddling으로 딸려오는 어제 종일/멀티데이를 시뮬레이션.
        let yesterdayAllDay = event(id: "yall", title: "어제종일", start: yStart, end: yStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true)
        let yesterdayMultiDay = event(id: "ymulti", title: "멀티데이", start: yStart.addingTimeInterval(9 * 3600), end: cal.startOfDay(for: now).addingTimeInterval(9 * 3600), colorHex: nil)
        let todayUpcoming = event(id: "t", title: "오늘예정", start: cal.startOfDay(for: now).addingTimeInterval(14 * 3600), end: cal.startOfDay(for: now).addingTimeInterval(15 * 3600), colorHex: nil)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [yesterdayAllDay, yesterdayMultiDay, todayUpcoming], now: now)

        let days = try #require(await service.startScheduleCalls.first)
        let ids = days.flatMap { $0.events.map(\.id) }
        #expect(!ids.contains("yall"))    // 어제 종일 제외
        #expect(!ids.contains("ymulti"))  // 어제 시작 멀티데이 제외
        #expect(ids.contains("t"))        // 오늘 예정 표시
        #expect(days.first?.label == "오늘")
    }

    @Test func startScheduleSkipsWhenNoUpcomingEvents() async throws {
        let service = RecordingLiveActivityService()

        let started = try await StartScheduleLiveActivityUseCase(service: service)(events: [], now: .now)

        #expect(started == false)
        #expect(await service.startScheduleCalls.isEmpty)   // 빈 일정이면 게시 자체를 안 한다
    }

    @Test func startScheduleSkipsWhenAllEventsEnded() async throws {
        let service = RecordingLiveActivityService()
        let now = Date.now
        let ended = event(id: "e", title: "끝남", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), colorHex: nil)

        let started = try await StartScheduleLiveActivityUseCase(service: service)(events: [ended], now: now)

        #expect(started == false)
        #expect(await service.startScheduleCalls.isEmpty)
    }

    @Test func startScheduleHidesEndedTimedEventsButKeepsAllDay() async throws {
        let service = RecordingLiveActivityService()
        let now = Date.now
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        let ended = event(id: "ended", title: "끝남", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), colorHex: nil)
        let ongoing = event(id: "ongoing", title: "진행중", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(1800), colorHex: nil)
        let future = event(id: "future", title: "예정", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: nil)
        // 종일은 시작이 자정(과거)이라도 항상 유지.
        let allDay = event(id: "allday", title: "종일", start: todayStart, end: todayStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [ended, ongoing, future, allDay], now: now)

        let days = try #require(await service.startScheduleCalls.first)
        let ids = days.flatMap { $0.events.map(\.id) }
        #expect(!ids.contains("ended"))     // 끝난 시간 이벤트 제외
        #expect(ids.contains("ongoing"))    // 진행 중 유지
        #expect(ids.contains("future"))     // 예정 유지
        #expect(ids.contains("allday"))     // 종일은 항상 유지
    }

    @Test func startScheduleSortsAllDayFirstWithinDay() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // now를 06:00로 고정, 시간 이벤트는 09:00~ → 지난-이벤트 필터에 안 걸리게.
        let now = today.addingTimeInterval(6 * 3600)
        let events = [
            event(id: "timed", title: "시간일정", start: today.addingTimeInterval(9 * 3600), end: today.addingTimeInterval(10 * 3600), colorHex: nil, isAllDay: false),
            event(id: "allday", title: "종일일정", start: today, end: today.addingTimeInterval(86_400), colorHex: nil, isAllDay: true),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: now)

        let firstDay = try #require(await service.startScheduleCalls.first?.first)
        // 종일이 위로.
        #expect(firstDay.events.map(\.id) == ["allday", "timed"])
        #expect(firstDay.events.first?.isAllDay == true)
    }

    // MARK: - Wrappers — forwarding (Reminder/Schedule. 집중 LA는 AlarmKit으로 이관됨)

    @Test func endReminderCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await EndReminderLiveActivityUseCase(service: service)()

        #expect(await service.endReminderCount == 1)
    }

    @Test func endScheduleCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await EndScheduleLiveActivityUseCase(service: service)()

        #expect(await service.endScheduleCount == 1)
    }

    @Test func syncCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await SyncLiveActivitiesUseCase(service: service)()

        #expect(await service.syncCount == 1)
    }

    // MARK: - Helpers

    private func reminder(id: String, title: String, listID: String = "list-1") -> Reminder {
        Reminder(
            id: id,
            title: title,
            isCompleted: false,
            notes: nil,
            dueDate: nil,
            listID: listID
        )
    }

    private func event(id: String, title: String, start: Date, end: Date, colorHex: String?, isAllDay: Bool = false) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            calendarColorHex: colorHex,
            isReadOnly: false
        )
    }
}

// MARK: - Mock service — actor로 호출 기록을 안전하게 보관

private final actor RecordingLiveActivityService: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startReminderCalls: [(listTitle: String, items: [LiveReminderItem], remaining: Int)] = []
    private(set) var endReminderCount = 0

    private(set) var startScheduleCalls: [[LiveScheduleDay]] = []
    private(set) var endScheduleCount = 0

    private(set) var syncCount = 0

    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int
    ) async throws {
        startReminderCalls.append((listTitle, items, remaining))
    }

    func endReminder() async {
        endReminderCount += 1
    }

    func startSchedule(days: [LiveScheduleDay]) async throws {
        startScheduleCalls.append(days)
    }

    func endSchedule() async {
        endScheduleCount += 1
    }

    func sync() async {
        syncCount += 1
    }
}
