//
//  ReminderMapper.swift
//  cue / Data
//

import EventKit

/// EventKit 모델 ↔ 도메인 엔티티 변환. 두 계층 사이 경계를 한 곳에 모은다.
enum ReminderMapper {
    /// `EKCalendar`(미리 알림 타입) → 도메인 `ReminderList`
    static func toList(_ calendar: EKCalendar) -> ReminderList {
        ReminderList(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: hex(from: calendar.cgColor)
        )
    }

    /// `CGColor` → "#RRGGBB" 6자리 hex. RGBA 컴포넌트가 없으면 nil.
    /// EventKit 캘린더 색은 sRGB 가정 — 별도 컬러 스페이스 변환은 하지 않는다.
    private static func hex(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(round(max(0, min(1, components[0])) * 255))
        let g = Int(round(max(0, min(1, components[1])) * 255))
        let b = Int(round(max(0, min(1, components[2])) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// `EKReminder` → 도메인 `Reminder`
    /// `includesTime`은 `dueDateComponents`에 시·분이 들어 있는지로 판단한다 —
    /// 시·분이 비어 있으면 EventKit이 종일 마감으로 취급한다.
    /// `recurrence`는 `recurrenceRules` 배열의 **첫 규칙**만 frequency·interval만 매핑한다.
    /// daysOfWeek 등 풍부한 표현은 다음 사이클에서.
    static func toReminder(_ reminder: EKReminder) -> Reminder {
        Reminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            includesTime: reminder.dueDateComponents?.hour != nil,
            recurrence: toRecurrence(reminder.recurrenceRules?.first),
            listID: reminder.calendar.calendarIdentifier
        )
    }

    /// `EKRecurrenceRule` → 도메인 `RecurrenceRule`. frequency·interval만 매핑.
    private static func toRecurrence(_ rule: EKRecurrenceRule?) -> RecurrenceRule? {
        guard let rule else { return nil }
        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }
        return RecurrenceRule(frequency: frequency, interval: rule.interval)
    }
}
