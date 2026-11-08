//
//  ReminderList.swift
//  cue / Domain
//

/// 미리 알림 리스트 — iOS "미리 알림" 앱의 리스트 하나에 대응하는 도메인 엔티티.
struct ReminderList: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var title: String
    var colorHex: String?
    /// EventKit 기본 미리알림 목록 여부 — 기본 목록 이름은 기기 언어에 따라 달라지므로
    /// 이름 대신 이 플래그로 판별한다(로케일 무관).
    var isDefault: Bool = false
    /// 내용을 못 바꾸는 목록(읽기 전용으로 공유받은 목록 등) — 목록 선택지·기본 목록에서 뺀다.
    /// 넣으면 저장이 실패한다.
    var isReadOnly: Bool = false
}

extension ReminderList {
    /// 스냅샷에 나중에 추가된 플래그가 없어도 읽는다 — 합성 디코더는 기본값을 안 써서
    /// 옛 스냅샷 하나 때문에 첫 페인트 캐시 전체를 버리게 된다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        isReadOnly = try container.decodeIfPresent(Bool.self, forKey: .isReadOnly) ?? false
    }
}
