//
//  ReminderMapper.swift
//  cue / Data
//

import EventKit

/// EventKit 모델 ↔ 도메인 엔티티 변환. 두 계층 사이 경계를 한 곳에 모은다.
enum ReminderMapper {
    /// `EKCalendar`(미리 알림 타입) → 도메인 `ReminderList`.
    /// `defaultListID`(EventKit 기본 미리알림 목록 id)와 일치하면 `isDefault`를 세운다.
    static func toList(_ calendar: EKCalendar, defaultListID: String? = nil) -> ReminderList {
        ReminderList(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: hex(from: calendar.cgColor),
            isDefault: calendar.calendarIdentifier == defaultListID
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
    /// `recurrence`는 `recurrenceRules` 배열의 **첫 규칙**을 매핑한다.
    static func toReminder(_ reminder: EKReminder) -> Reminder {
        Reminder(
            id: reminder.calendarItemIdentifier,
            title: reminder.title ?? "",
            isCompleted: reminder.isCompleted,
            notes: reminder.notes,
            dueDate: reminder.dueDateComponents?.date,
            includesTime: reminder.dueDateComponents?.hour != nil,
            recurrence: toRecurrence(reminder.recurrenceRules?.first),
            creationDate: reminder.creationDate,
            listID: reminder.calendar.calendarIdentifier
        )
    }

    /// cue가 관리하는 알람인지 — **마감 시각 절대 알람(위치 없음)**만 해당한다.
    /// 그 외(위치·상대 오프셋·위치 붙은 절대)는 사용자가 미리알림 앱에서 단 것일 수 있어
    /// 편집 저장 시 보존한다 — 일정 편집의 `.custom` 알림 보존과 같은 계약.
    static func isCueManagedDueAlarm(_ alarm: EKAlarm) -> Bool {
        alarm.absoluteDate != nil && alarm.structuredLocation == nil
    }

    /// 기존 EK 규칙과 도메인 규칙의 동치 판정 — 동치면 저장 시 재기록하지 않아, 도메인이
    /// 표현 못 하는 원본 세부(횟수 종료 등)가 깎이지 않는다(일정 `.foreign` 보존과 같은 계약).
    /// 판정 기준: 기존 규칙을 도메인으로 읽었을 때 편집 결과와 같은가 — 시트가 반복을
    /// 안 건드렸으면 읽은 값을 그대로 돌려주므로 항상 동치가 된다.
    static func isEquivalentRecurrence(_ existing: EKRecurrenceRule?, to domain: RecurrenceRule?) -> Bool {
        toRecurrence(existing) == domain
    }

    /// `EKRecurrenceRule` → 도메인 `RecurrenceRule`.
    /// 요일/일자/월/서수 요일(setPositions·weekNumber 두 인코딩)·종료 날짜까지 매핑한다.
    /// 표현 못 하는 부가 조건(횟수 종료·연중 주차 등)은 **빈도·간격만으로 단순화** —
    /// nil로 잃는 것보다 낫고, 저장 시 그 단순화 형태로 재기록된다(문서화된 손실).
    static func toRecurrence(_ rule: EKRecurrenceRule?) -> RecurrenceRule? {
        guard let rule else { return nil }
        let frequency: RecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        @unknown default: return nil
        }
        let fallback = RecurrenceRule(frequency: frequency, interval: rule.interval)

        // 횟수 종료는 도메인에 없다 — 단순화 폴백.
        if let end = rule.recurrenceEnd, end.endDate == nil { return fallback }
        let endDate = rule.recurrenceEnd?.endDate

        var weekdays: Set<Int> = []
        var ordinal: Int?
        var ordinalWeekday: Int?
        if let positions = rule.setPositions {
            guard positions.count == 1, frequency == .monthly || frequency == .yearly,
                  let days = rule.daysOfTheWeek, days.count == 1, days[0].weekNumber == 0,
                  rule.daysOfTheMonth == nil
            else { return fallback }
            ordinal = positions[0].intValue
            ordinalWeekday = days[0].dayOfTheWeek.rawValue
        } else if let days = rule.daysOfTheWeek {
            if frequency == .weekly, days.allSatisfy({ $0.weekNumber == 0 }) {
                weekdays = Set(days.map { $0.dayOfTheWeek.rawValue })
            } else if frequency == .monthly, days.count == 1, days[0].weekNumber != 0,
                      rule.daysOfTheMonth == nil {
                ordinal = days[0].weekNumber
                ordinalWeekday = days[0].dayOfTheWeek.rawValue
            } else {
                return fallback
            }
        }
        var monthDays: Set<Int> = []
        if let days = rule.daysOfTheMonth {
            guard frequency == .monthly, days.allSatisfy({ $0.intValue >= 1 }) else { return fallback }
            monthDays = Set(days.map(\.intValue))
        }
        var months: Set<Int> = []
        if let list = rule.monthsOfTheYear {
            guard frequency == .yearly else { return fallback }
            months = Set(list.map(\.intValue))
        }

        return RecurrenceRule(
            frequency: frequency, interval: rule.interval,
            weekdays: weekdays, monthDays: monthDays, months: months,
            ordinal: ordinal, ordinalWeekday: ordinalWeekday, endDate: endDate
        )
    }

    /// 도메인 `RecurrenceRule` → `EKRecurrenceRule`. 서수 요일은 setPositions로 인코딩
    /// (Apple 캘린더·미리 알림과 같은 방식), 종료 날짜는 recurrenceEnd로.
    static func toEKRecurrenceRule(_ rule: RecurrenceRule?) -> EKRecurrenceRule? {
        guard let rule else { return nil }
        let frequency: EKRecurrenceFrequency
        switch rule.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        }
        let usesOrdinal = (rule.frequency == .monthly || rule.frequency == .yearly)
            && rule.ordinal != nil && rule.ordinalWeekday != nil
        let ordinalDays = rule.ordinalWeekday
            .flatMap(EKWeekday.init(rawValue:))
            .map { [EKRecurrenceDayOfWeek($0)] }
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: rule.interval,
            daysOfTheWeek: usesOrdinal
                ? ordinalDays
                : (rule.frequency == .weekly && !rule.weekdays.isEmpty
                    ? rule.weekdays.sorted().compactMap { EKWeekday(rawValue: $0).map { EKRecurrenceDayOfWeek($0) } }
                    : nil),
            daysOfTheMonth: !usesOrdinal && rule.frequency == .monthly && !rule.monthDays.isEmpty
                ? rule.monthDays.sorted().map(NSNumber.init(value:))
                : nil,
            monthsOfTheYear: rule.frequency == .yearly && !rule.months.isEmpty
                ? rule.months.sorted().map(NSNumber.init(value:))
                : nil,
            weeksOfTheYear: nil, daysOfTheYear: nil,
            setPositions: usesOrdinal ? rule.ordinal.map { [NSNumber(value: $0)] } : nil,
            end: rule.endDate.map(EKRecurrenceEnd.init(end:))
        )
    }
}
