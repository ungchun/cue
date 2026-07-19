//
//  FetchCalendarsUseCase.swift
//  cue / Domain
//

/// 사용자의 캘린더(달력) 목록 전체를 가져온다 — 설정 "볼 캘린더 선택"용.
struct FetchCalendarsUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [EventCalendar] {
        try await repository.fetchCalendars()
    }
}
