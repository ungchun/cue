//
//  ReminderLocationAlarm+Labels.swift
//  cue / Presentation
//

import Foundation

/// 위치 알림 도착/출발 문구 — 편집 폼(세그먼트)과 보기 화면 공용. Apple 미리 알림 문구를 따른다.
extension ReminderLocationAlarm.Proximity {
    var label: String {
        switch self {
        case .arriving: String(localized: "Arriving")
        case .leaving: String(localized: "Leaving")
        }
    }
}
