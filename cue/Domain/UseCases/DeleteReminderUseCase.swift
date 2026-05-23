//
//  DeleteReminderUseCase.swift
//  cue / Domain
//

/// 미리 알림 항목을 삭제한다.
struct DeleteReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(reminderID: String) async throws {
        try await repository.deleteReminder(reminderID: reminderID)
    }
}
