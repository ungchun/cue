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

    /// 갱신된 항목을 돌려준다 — 같은 id를 로컬에서 in-place 치환하기 위함(add와 같은 계약).
    @discardableResult
    func callAsFunction(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date? = nil,
        includesTime: Bool = false
    ) async throws -> Reminder {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation(String(localized: "Please enter a title."))
        }
        return try await repository.updateReminder(
            reminderID: reminderID,
            title: trimmed,
            notes: ReminderNotes.normalized(notes),
            dueDate: dueDate,
            includesTime: includesTime
        )
    }
}
