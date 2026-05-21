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
            colorHex: nil
        )
    }

    /// `EKReminder` → 도메인 `Reminder`
    static func toReminder(_ reminder: EKReminder) -> Reminder {
        Reminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            listID: reminder.calendar.calendarIdentifier
        )
    }
}
