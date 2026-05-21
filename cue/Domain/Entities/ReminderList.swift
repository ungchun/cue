//
//  ReminderList.swift
//  cue / Domain
//

/// 미리 알림 리스트 — iOS "미리 알림" 앱의 리스트 하나에 대응하는 도메인 엔티티.
struct ReminderList: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var colorHex: String?
}
