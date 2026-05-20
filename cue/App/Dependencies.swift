//
//  Dependencies.swift
//  cue / App
//

import SwiftUI

/// 앱 전역 의존성 묶음. `CompositionRoot`에서 조립되어 `@Environment`로 주입된다.
/// View / ViewModel은 이 묶음을 통해 UseCase에만 접근한다.
struct Dependencies: Sendable {
    var fetchItems: FetchItemsUseCase
    var addItem: AddItemUseCase
    var deleteItem: DeleteItemUseCase
}

extension EnvironmentValues {
    /// 기본값은 인메모리 구현 — Xcode Preview가 `CompositionRoot` 없이도 동작한다.
    @Entry var dependencies: Dependencies = .preview
}

extension Dependencies {
    /// 프리뷰·테스트용 인메모리 의존성.
    static var preview: Dependencies {
        let repository = InMemoryItemRepository(seed: [
            Item(title: "예시 항목", note: "InMemoryItemRepository 제공"),
        ])
        return Dependencies(
            fetchItems: FetchItemsUseCase(repository: repository),
            addItem: AddItemUseCase(repository: repository),
            deleteItem: DeleteItemUseCase(repository: repository)
        )
    }
}
