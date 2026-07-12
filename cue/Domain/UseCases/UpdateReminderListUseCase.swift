//
//  UpdateReminderListUseCase.swift
//  cue / Domain
//

import Foundation

/// 기존 리스트의 이름·색을 갱신한다. 제목 검증은 여기서 — 빈 제목은 받지 않는다.
struct UpdateReminderListUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction(listID: String, title: String, colorHex: String?) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation(String(localized: "Please enter a list name."))
        }
        try await repository.updateList(listID: listID, title: trimmed, colorHex: colorHex)
    }
}
