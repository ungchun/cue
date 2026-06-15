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

    // MARK: - StartSchedule — today/tomorrow 분리 + 필드 매핑

    @Test func startScheduleMapsTodayAndTomorrowSeparately() async throws {
        let service = RecordingLiveActivityService()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let today = [event(id: "t1", title: "회의", start: now, end: now.addingTimeInterval(3600), colorHex: "#FF0000")]
        let tomorrow = [event(id: "tm1", title: "출근", start: now.addingTimeInterval(86_400), end: now.addingTimeInterval(86_400 + 3600), colorHex: nil)]

        try await StartScheduleLiveActivityUseCase(service: service)(
            today: today,
            tomorrow: tomorrow
        )

        let call = try #require(await service.startScheduleCalls.first)
        #expect(call.today.map(\.id) == ["t1"])
        #expect(call.tomorrow.map(\.id) == ["tm1"])
        #expect(call.today.first?.title == "회의")
        #expect(call.today.first?.calendarColorHex == "#FF0000")
        #expect(call.tomorrow.first?.calendarColorHex == nil)
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

    private func event(id: String, title: String, start: Date, end: Date, colorHex: String?) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: false,
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

    private(set) var startScheduleCalls: [(today: [LiveEventItem], tomorrow: [LiveEventItem])] = []
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

    func startSchedule(
        today: [LiveEventItem],
        tomorrow: [LiveEventItem]
    ) async throws {
        startScheduleCalls.append((today, tomorrow))
    }

    func endSchedule() async {
        endScheduleCount += 1
    }

    func sync() async {
        syncCount += 1
    }
}
