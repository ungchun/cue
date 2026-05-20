//
//  InMemoryItemRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. SwiftData·iCloud 없이 동작한다.
///
/// `actor`로 격리해 `Sendable`을 만족하며, 어느 컨텍스트에서든 생성할 수 있다
/// (그래서 `Dependencies.preview`가 메인 액터 격리 없이 동작한다).
actor InMemoryItemRepository: ItemRepository {
    private var storage: [UUID: Item]

    init(seed: [Item] = []) {
        storage = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    func fetchAll() throws -> [Item] {
        storage.values.sorted { $0.createdAt > $1.createdAt }
    }

    func add(_ item: Item) throws {
        storage[item.id] = item
    }

    func update(_ item: Item) throws {
        guard storage[item.id] != nil else { throw DomainError.notFound }
        storage[item.id] = item
    }

    func delete(id: UUID) throws {
        storage[id] = nil
    }
}
