//
//  ItemModel.swift
//  cue / Data
//

import Foundation
import SwiftData

/// SwiftData 영속성 모델. Data 계층 밖으로 노출하지 않는다.
/// (Domain은 `Item` 구조체만 사용 — 변환은 `ItemMapper` 담당)
///
/// ⚠️ iCloud(CloudKit) 동기화 제약 — 위반 시 동기화가 조용히 비활성화된다:
/// - `@Attribute(.unique)` 사용 금지 → 유니크는 UseCase에서 보장
/// - 모든 속성은 옵셔널이거나 기본값을 가져야 함
/// - 모든 관계는 옵셔널 + 역관계(inverse) 필수
/// - 출시 후 스키마는 "추가만 가능" (이름 변경·삭제·타입 변경 불가)
@Model
final class ItemModel {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var createdAt: Date = Date.now

    init(
        id: UUID = UUID(),
        title: String = "",
        note: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.createdAt = createdAt
    }
}
