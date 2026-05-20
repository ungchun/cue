//
//  SwiftDataItemRepository.swift
//  cue / Data
//

import Foundation
import SwiftData

/// `ItemRepository`의 SwiftData 구현.
///
/// 메인 `ModelContext`를 사용하므로 `@MainActor`로 격리한다.
/// 동기 메서드가 프로토콜의 `async` 요구사항을 충족한다.
@MainActor
final class SwiftDataItemRepository: ItemRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() throws -> [Item] {
        let descriptor = FetchDescriptor<ItemModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(ItemMapper.toDomain)
    }

    func add(_ item: Item) throws {
        context.insert(ItemMapper.makeModel(from: item))
        try context.save()
    }

    func update(_ item: Item) throws {
        guard let model = try findModel(id: item.id) else {
            throw DomainError.notFound
        }
        ItemMapper.apply(item, to: model)
        try context.save()
    }

    func delete(id: UUID) throws {
        guard let model = try findModel(id: id) else { return }
        context.delete(model)
        try context.save()
    }

    private func findModel(id: UUID) throws -> ItemModel? {
        var descriptor = FetchDescriptor<ItemModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
