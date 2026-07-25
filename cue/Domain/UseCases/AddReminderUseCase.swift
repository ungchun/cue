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

    /// 저장된 항목(실제 id 포함)을 돌려준다 — ViewModel이 재조회를 기다리지 않고
    /// 로컬 목록에 즉시(낙관적으로) 반영해 저장 시 행 깜빡임을 없앤다.
    @discardableResult
    func callAsFunction(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        includesTime: Bool = false,
        recurrence: RecurrenceRule? = nil,
        listID: String
    ) async throws -> Reminder {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation(String(localized: "Please enter a title."))
        }
        return try await repository.addReminder(
            title: trimmed,
            notes: ReminderNotes.normalized(notes),
            dueDate: dueDate,
            includesTime: includesTime,
            // 반복은 마감일 전제 — 날짜가 없으면 무시(도메인 불변식).
            recurrence: dueDate != nil ? recurrence : nil,
            toListID: listID
        )
    }
}
