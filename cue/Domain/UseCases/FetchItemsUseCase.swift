//
//  FetchItemsUseCase.swift
//  cue / Domain
//

import Foundation

/// 비즈니스 동작 1개 = UseCase 1개. 상태를 갖지 않으며 Repository를 조합한다.
struct FetchItemsUseCase: Sendable {
    private let repository: any ItemRepository

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    /// 생성일 내림차순으로 정렬해 반환한다.
    func callAsFunction() async throws -> [Item] {
        try await repository.fetchAll().sorted { $0.createdAt > $1.createdAt }
    }
}
