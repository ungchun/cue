//
//  AddReminderUseCase.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목 추가 — 제목 검증 같은 비즈니스 규칙은 UseCase에 둔다.
struct AddReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        includesTime: Bool = false,
        listID: String
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("제목을 입력해 주세요.")
        }
        try await repository.addReminder(
            title: trimmed,
            notes: ReminderNotes.normalized(notes),
            dueDate: dueDate,
            includesTime: includesTime,
            toListID: listID
        )
    }
}
