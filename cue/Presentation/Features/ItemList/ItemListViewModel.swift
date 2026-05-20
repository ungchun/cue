//
//  ItemListViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// `ItemListView`의 상태 + 동작. UseCase에만 의존하며 SwiftUI를 import하지 않는다.
@MainActor
@Observable
final class ItemListViewModel {
    private let fetchItems: FetchItemsUseCase
    private let addItem: AddItemUseCase
    private let deleteItem: DeleteItemUseCase

    private(set) var items: [Item] = []
    private(set) var isLoading = false
    var errorMessage: String?

    init(dependencies: Dependencies) {
        self.fetchItems = dependencies.fetchItems
        self.addItem = dependencies.addItem
        self.deleteItem = dependencies.deleteItem
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await fetchItems()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(title: String) async {
        do {
            try await addItem(title: title)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ item: Item) async {
        do {
            try await deleteItem(id: item.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
