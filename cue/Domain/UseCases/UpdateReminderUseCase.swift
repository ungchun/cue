//
//  UpdateReminderUseCase.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목의 제목·메모를 수정한다. 제목 검증은 추가와 동일하게 UseCase에 둔다.
struct UpdateReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(reminderID: String, title: String, notes: String?) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("제목을 입력해 주세요.")
        }
        try await repository.updateReminder(
            reminderID: reminderID,
            title: trimmed,
            notes: ReminderNotes.normalized(notes)
        )
    }
}
