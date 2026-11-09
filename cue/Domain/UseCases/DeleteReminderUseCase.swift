//
//  DeleteReminderUseCase.swift
//  cue / Domain
//

/// 미리 알림 항목을 삭제한다. 반복 항목은 `span`으로 이번 회차만인지 이후 전부인지 고른다.
struct DeleteReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(reminderID: String, span: ReminderDeleteSpan = .futureOccurrences) async throws {
        switch span {
        case .thisOccurrence: try await repository.deleteOccurrence(reminderID: reminderID)
        case .futureOccurrences: try await repository.deleteReminder(reminderID: reminderID)
        }
    }
}
