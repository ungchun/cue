//
//  ItemMapper.swift
//  cue / Data
//

import Foundation

/// 영속성 모델 ↔ 도메인 엔티티 변환. 두 계층 사이 경계를 한 곳에 모은다.
enum ItemMapper {
    /// 영속성 모델 → 도메인 엔티티
    static func toDomain(_ model: ItemModel) -> Item {
        Item(
            id: model.id,
            title: model.title,
            note: model.note,
            createdAt: model.createdAt
        )
    }

    /// 도메인 엔티티 → 새 영속성 모델
    static func makeModel(from item: Item) -> ItemModel {
        ItemModel(
            id: item.id,
            title: item.title,
            note: item.note,
            createdAt: item.createdAt
        )
    }

    /// 도메인 엔티티의 값을 기존 영속성 모델에 반영 (업데이트)
    static func apply(_ item: Item, to model: ItemModel) {
        model.title = item.title
        model.note = item.note
        model.createdAt = item.createdAt
    }
}
