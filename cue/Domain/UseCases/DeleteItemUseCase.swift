//
//  DeleteItemUseCase.swift
//  cue / Domain
//

import Foundation

/// 항목 삭제.
struct DeleteItemUseCase: Sendable {
    private let repository: any ItemRepository

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func callAsFunction(id: UUID) async throws {
        try await repository.delete(id: id)
    }
}
