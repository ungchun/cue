//
//  Reminder.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목 하나 — iOS "미리 알림" 앱의 한 항목에 대응하는 도메인 엔티티.
struct Reminder: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var isCompleted: Bool
    var notes: String?
    var dueDate: Date?
    let listID: String
}
