//
//  ModelContainerFactory.swift
//  cue / Data
//

import Foundation
import SwiftData

/// `ModelContainer` 생성을 한 곳에서 담당한다.
///
/// ## iCloud 동기화
/// `ModelConfiguration`의 `cloudKitDatabase`는 기본값 `.automatic` 이다.
/// → Xcode에서 **Signing & Capabilities → iCloud → CloudKit** 역량을 추가하면
///   코드 변경 없이 동기화가 자동으로 켜진다. 역량이 없으면 로컬 전용으로 동작한다.
enum ModelContainerFactory {
    /// 앱이 사용하는 전체 스키마. 새 `@Model`을 추가하면 이 배열에 등록한다.
    /// (computed — Swift 6 엄격 동시성에서 `static let`의 Sendable 이슈를 피한다)
    static var schema: Schema {
        Schema([
            ItemModel.self,
        ])
    }

    /// - Parameter inMemory: `true`면 디스크에 저장하지 않는다 (테스트·프리뷰용).
    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("ModelContainer 생성 실패: \(error)")
        }
    }
}
