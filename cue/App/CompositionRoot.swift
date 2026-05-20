//
//  CompositionRoot.swift
//  cue / App
//

import SwiftData

/// 조립 루트(Composition Root) — 구체 구현을 생성해 의존성을 연결하는 **유일한** 장소.
/// Data 계층의 구체 타입(`SwiftData...`)은 오직 여기서만 생성한다.
@MainActor
struct CompositionRoot {
    let modelContainer: ModelContainer
    let dependencies: Dependencies

    init() {
        let container = ModelContainerFactory.make()
        let repository = SwiftDataItemRepository(context: container.mainContext)

        self.modelContainer = container
        self.dependencies = Dependencies(
            fetchItems: FetchItemsUseCase(repository: repository),
            addItem: AddItemUseCase(repository: repository),
            deleteItem: DeleteItemUseCase(repository: repository)
        )
    }
}
