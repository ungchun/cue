//
//  Item.swift
//  cue / Domain
//

import Foundation

/// 도메인 엔티티 — 영속성·UI와 무관한 순수 Swift 모델.
///
/// ⚠️ `Item`은 구조 예시용 placeholder 입니다.
/// 앱 컨셉이 정해지면 실제 도메인 엔티티로 교체하세요.
struct Item: Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
    }
}
