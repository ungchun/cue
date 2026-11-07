//
//  UpdateReminderUseCase.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목을 수정한다. 제목 검증·메모 정규화는 추가와 동일하게 UseCase에 둔다.
struct UpdateReminderUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    /// 갱신된 항목을 돌려준다 — 같은 id를 로컬에서 in-place 치환하기 위함(add와 같은 계약).
    @discardableResult
    func callAsFunction(reminderID: String, changes: ReminderChanges) async throws -> Reminder {
        let trimmed = changes.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation(String(localized: "Please enter a title."))
        }
        var normalized = changes
        normalized.title = trimmed
        normalized.notes = ReminderNotes.normalized(changes.notes)
        // 반복·시각 지정은 마감일 전제 — 날짜가 빠지면 함께 지워 도메인 불변식을 지킨다.
        if changes.dueDate == nil {
            normalized.includesTime = false
            normalized.recurrence = nil
        }
        return try await repository.updateReminder(reminderID: reminderID, changes: normalized)
    }
}
