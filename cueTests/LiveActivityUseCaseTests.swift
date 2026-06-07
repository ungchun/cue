//
//  LiveActivityUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct LiveActivityUseCaseTests {

    // MARK: - StartReminder — cap / remaining / mapping

    @Test func startReminderCapsItemsAtSixAndComputesRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...8).map { reminder(id: "r\($0)", title: "할일 \($0)") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘",
            reminders: reminders
        )

        let calls = await service.startReminderCalls
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.listTitle == "오늘")
        #expect(call.items.count == 6)
        #expect(call.items.map(\.id) == ["r1", "r2", "r3", "r4", "r5", "r6"])
        #expect(call.items.first?.title == "할일 1")
        #expect(call.remaining == 2)
    }

    @Test func startReminderWithExactCapHasZeroRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...6).map { reminder(id: "r\($0)", title: "X") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "전체",
            reminders: reminders
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.count == 6)
        #expect(call.remaining == 0)
    }

    @Test func startReminderEmptyListPassesEmptyItems() async throws {
        let service = RecordingLiveActivityService()

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "비어있음",
            reminders: []
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.isEmpty)
        #expect(call.remaining == 0)
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

    // MARK: - Wrappers — forwarding

    @Test func startFocusForwardsAllArguments() async throws {
        let service = RecordingLiveActivityService()
        let id = UUID()
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let start = end.addingTimeInterval(-1500)

        try await StartFocusLiveActivityUseCase(service: service)(
            sessionID: id,
            sessionTitle: "딥워크",
            colorHex: "#FFD400",
            phase: .focus,
            phaseStartDate: start,
            phaseEndDate: end
        )

        let call = try #require(await service.startFocusCalls.first)
        #expect(call.sessionID == id)
        #expect(call.sessionTitle == "딥워크")
        #expect(call.colorHex == "#FFD400")
        #expect(call.phase == .focus)
        #expect(call.phaseStartDate == start)
        #expect(call.phaseEndDate == end)
    }

    @Test func startFocusForwardsNilColorHex() async throws {
        let service = RecordingLiveActivityService()
        let id = UUID()
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let start = end.addingTimeInterval(-1500)

        try await StartFocusLiveActivityUseCase(service: service)(
            sessionID: id,
            sessionTitle: "기본 세션",
            colorHex: nil,
            phase: .focus,
            phaseStartDate: start,
            phaseEndDate: end
        )

        let call = try #require(await service.startFocusCalls.first)
        #expect(call.colorHex == nil)
    }

    @Test func updateFocusForwardsPauseTime() async throws {
        let service = RecordingLiveActivityService()
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let start = end.addingTimeInterval(-1500)
        let pause = end.addingTimeInterval(-30)

        try await UpdateFocusLiveActivityUseCase(service: service)(
            phase: .focus,
            phaseStartDate: start,
            phaseEndDate: end,
            pauseTime: pause
        )

        let call = try #require(await service.updateFocusCalls.first)
        #expect(call.phase == .focus)
        #expect(call.phaseStartDate == start)
        #expect(call.phaseEndDate == end)
        #expect(call.pauseTime == pause)
    }

    @Test func endFocusCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await EndFocusLiveActivityUseCase(service: service)()

        #expect(await service.endFocusCount == 1)
    }

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

    private func reminder(id: String, title: String) -> Reminder {
        Reminder(
            id: id,
            title: title,
            isCompleted: false,
            notes: nil,
            dueDate: nil,
            listID: "list-1"
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

    private(set) var startFocusCalls: [(sessionID: UUID, sessionTitle: String, colorHex: String?, phase: LiveFocusPhase, phaseStartDate: Date, phaseEndDate: Date)] = []
    private(set) var updateFocusCalls: [(phase: LiveFocusPhase, phaseStartDate: Date, phaseEndDate: Date, pauseTime: Date?)] = []
    private(set) var endFocusCount = 0

    private(set) var startReminderCalls: [(listTitle: String, items: [LiveReminderItem], remaining: Int)] = []
    private(set) var endReminderCount = 0

    private(set) var startScheduleCalls: [(today: [LiveEventItem], tomorrow: [LiveEventItem])] = []
    private(set) var endScheduleCount = 0

    private(set) var syncCount = 0

    func startFocus(
        sessionID: UUID,
        sessionTitle: String,
        colorHex: String?,
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date
    ) async throws {
        startFocusCalls.append((sessionID, sessionTitle, colorHex, phase, phaseStartDate, phaseEndDate))
    }

    func updateFocus(
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date,
        pauseTime: Date?
    ) async throws {
        updateFocusCalls.append((phase, phaseStartDate, phaseEndDate, pauseTime))
    }

    func endFocus() async {
        endFocusCount += 1
    }

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
