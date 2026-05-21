//
//  FetchRemindersUseCase.swift
//  cue / Domain
//

/// 모든 리스트의 미리 알림 항목 전체를 가져온다.
struct FetchRemindersUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [Reminder] {
        try await repository.fetchReminders()
    }
}
