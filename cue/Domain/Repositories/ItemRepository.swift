//
//  ItemRepository.swift
//  cue / Domain
//

import Foundation

/// 저장소 추상화 — Domain이 "소유"하는 프로토콜. 구현체는 Data 계층에 둔다.
///
/// Domain은 SwiftData·CloudKit 같은 세부 기술을 절대 알지 못한다.
/// 이 경계 덕분에 저장 방식이 바뀌어도 Domain/Presentation은 영향받지 않는다.
protocol ItemRepository: Sendable {
    func fetchAll() async throws -> [Item]
    func add(_ item: Item) async throws
    func update(_ item: Item) async throws
    func delete(id: UUID) async throws
}
