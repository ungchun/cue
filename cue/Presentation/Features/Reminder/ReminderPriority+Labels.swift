//
//  ReminderPriority+Labels.swift
//  cue / Presentation
//

import Foundation

/// 우선순위 표시 문구 — 편집 폼(피커)과 보기 화면이 같은 문구를 쓰도록 한 곳에 둔다.
extension ReminderPriority {
    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }
}
