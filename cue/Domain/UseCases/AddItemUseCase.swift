//
//  AddItemUseCase.swift
//  cue / Domain
//

import Foundation

/// 항목 추가 — 검증 같은 비즈니스 규칙은 UseCase에 둔다.
struct AddItemUseCase: Sendable {
    private let repository: any ItemRepository

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func callAsFunction(title: String, note: String = "") async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DomainError.validation("제목을 입력해 주세요.")
        }
        try await repository.add(Item(title: trimmed, note: note))
    }
}
