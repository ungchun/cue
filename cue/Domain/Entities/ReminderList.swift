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
}
