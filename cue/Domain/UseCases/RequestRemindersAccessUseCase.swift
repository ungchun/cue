//
//  RequestRemindersAccessUseCase.swift
//  cue / Domain
//

/// 미리 알림 접근 권한 요청 — 필요 시 시스템 프롬프트를 띄우고 결과 상태를 돌려준다.
struct RequestRemindersAccessUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> RemindersAccess {
        await repository.requestAccess()
    }
}
