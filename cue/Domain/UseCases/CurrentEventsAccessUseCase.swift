//
//  CurrentEventsAccessUseCase.swift
//  cue / Domain
//

/// 캘린더 접근 권한의 현재 상태 조회 — 프롬프트를 절대 띄우지 않는다.
/// 앱 시작 프리페치가 "이미 허용된 경우에만" 동작하기 위한 경로.
struct CurrentEventsAccessUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> EventsAccess {
        await repository.currentAccess()
    }
}
