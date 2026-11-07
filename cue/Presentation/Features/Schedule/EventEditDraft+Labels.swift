//
//  EventEditDraft+Labels.swift
//  cue / Presentation
//

import EventKit
import Foundation

/// 드래프트 옵션의 표시 문구 — 편집 폼(메뉴)과 보기 화면이 같은 문구를 쓰도록 한 곳에 둔다.
extension EventEditDraft {
    /// "다음으로 표시" 값 문구. 지원 안 함은 빈 문자열(호출처가 행을 숨긴다).
    static func label(for availability: EKEventAvailability) -> String {
        switch availability {
        case .busy: String(localized: "Busy")
        case .free: String(localized: "Free")
        case .tentative: String(localized: "Tentative")
        case .unavailable: String(localized: "Unavailable")
        default: ""
        }
    }
}

extension EventEditDraft.Recurrence {
    /// 반복 메뉴 문구. 사용자화·외부 규칙은 "사용자화"(요약은 CustomRule.summaryText).
    var label: String {
        switch self {
        case .none: String(localized: "Never")
        case .daily: String(localized: "Every Day")
        case .weekly: String(localized: "Every Week")
        case .biweekly: String(localized: "Every 2 Weeks")
        case .monthly: String(localized: "Every Month")
        case .yearly: String(localized: "Every Year")
        case .custom, .foreign: String(localized: "Custom")
        }
    }
}

extension EventEditDraft.Alarm {
    /// 알림 메뉴 문구. 사용자 지정(절대 일시)·보존 알림은 "사용자화" — 일시는 별도 행이 보여준다.
    var label: String {
        switch self {
        case .none: return String(localized: "None")
        case .atTime: return String(localized: "At time of event")
        case .absolute, .custom: return String(localized: "Custom")
        case .daysBeforeAt9AM(let days):
            switch days {
            case 0: return String(localized: "On day of event (9 AM)")
            case 1: return String(localized: "1 day before (9 AM)")
            case 2: return String(localized: "2 days before (9 AM)")
            default: return String(localized: "1 week before (9 AM)")
            }
        case .minutesBefore(let minutes):
            if minutes < 60 { return String(localized: "\(minutes) minutes before") }
            if minutes == 60 { return String(localized: "1 hour before") }
            if minutes < 1_440 { return String(localized: "\(minutes / 60) hours before") }
            if minutes == 1_440 { return String(localized: "1 day before") }
            if minutes < 10_080 { return String(localized: "\(minutes / 1_440) days before") }
            return String(localized: "1 week before")
        }
    }
}
