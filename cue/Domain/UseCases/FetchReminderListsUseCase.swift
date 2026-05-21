//
//  FetchReminderListsUseCase.swift
//  cue / Domain
//

/// 미리 알림 리스트 전체를 가져온다.
struct FetchReminderListsUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [ReminderList] {
        try await repository.fetchLists()
    }
}
