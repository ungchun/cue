//
//  FetchEventsUseCase.swift
//  cue / Domain
//

import Foundation

/// 주어진 기간의 캘린더 이벤트를 가져온다. 범위 경계와 겹치는 이벤트도 포함.
struct FetchEventsUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction(from: Date, to: Date) async throws -> [CalendarEvent] {
        try await repository.fetchEvents(from: from, to: to)
    }
}
