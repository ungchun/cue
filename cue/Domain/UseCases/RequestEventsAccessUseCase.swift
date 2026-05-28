//
//  RequestEventsAccessUseCase.swift
//  cue / Domain
//

/// 캘린더 접근 권한 요청 — 필요 시 시스템 프롬프트를 띄우고 결과 상태를 돌려준다.
/// `RequestRemindersAccessUseCase`와 같은 형태.
struct RequestEventsAccessUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> EventsAccess {
        await repository.requestAccess()
    }
}
