//
//  EventsUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct EventsUseCaseTests {

    @Test func requestAccessGrantsWhenNotDetermined() async {
        let repository = InMemoryEventsRepository(access: .notDetermined)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .granted)
    }

    @Test func requestAccessKeepsDeniedState() async {
        let repository = InMemoryEventsRepository(access: .denied)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .denied)
    }

    @Test func requestAccessKeepsGrantedState() async {
        let repository = InMemoryEventsRepository(access: .granted)

        let result = await RequestEventsAccessUseCase(repository: repository)()

        #expect(result == .granted)
    }

    // MARK: - fetchEvents

    private func event(
        id: String,
        title: String = "이벤트",
        start: Date,
        end: Date,
        isAllDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title,
            startDate: start, endDate: end,
            isAllDay: isAllDay, calendarColorHex: nil
        )
    }

    @Test func fetchEventsReturnsEventsWithinRange() async throws {
        let from = Date(timeIntervalSince1970: 1_700_000_000) // 임의 기준
        let to = from.addingTimeInterval(7 * 24 * 60 * 60) // +7일
        let inRange = event(id: "in", start: from.addingTimeInterval(60 * 60), end: from.addingTimeInterval(2 * 60 * 60))
        let outBefore = event(id: "before", start: from.addingTimeInterval(-3 * 60 * 60), end: from.addingTimeInterval(-2 * 60 * 60))
        let outAfter = event(id: "after", start: to.addingTimeInterval(60 * 60), end: to.addingTimeInterval(2 * 60 * 60))
        let repository = InMemoryEventsRepository(access: .granted, events: [inRange, outBefore, outAfter])

        let result = try await FetchEventsUseCase(repository: repository)(from: from, to: to)

        #expect(result.map(\.id) == ["in"])
    }

    @Test func fetchEventsIncludesEventStraddlingRange() async throws {
        // 범위 시작 전에 시작했지만 범위 안에서 끝나는 이벤트는 포함되어야 한다.
        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let to = from.addingTimeInterval(24 * 60 * 60)
        let straddling = event(
            id: "straddle",
            start: from.addingTimeInterval(-2 * 60 * 60),
            end: from.addingTimeInterval(60 * 60)
        )
        let repository = InMemoryEventsRepository(access: .granted, events: [straddling])

        let result = try await FetchEventsUseCase(repository: repository)(from: from, to: to)

        #expect(result.map(\.id) == ["straddle"])
    }

    @Test func fetchEventsEmptyWhenNoneInRange() async throws {
        let from = Date(timeIntervalSince1970: 1_700_000_000)
        let to = from.addingTimeInterval(24 * 60 * 60)
        let repository = InMemoryEventsRepository(access: .granted, events: [])

        let result = try await FetchEventsUseCase(repository: repository)(from: from, to: to)

        #expect(result.isEmpty)
    }
}
