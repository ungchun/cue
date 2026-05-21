//
//  ToggleReminderCompletionUseCase.swift
//  cue / Domain
//

/// 미리 알림 항목의 완료 상태를 뒤집는다.
struct ToggleReminderCompletionUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(_ reminder: Reminder) async throws {
        try await repository.setCompleted(!reminder.isCompleted, reminderID: reminder.id)
    }
}
