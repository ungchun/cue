//
//  ReminderMapper.swift
//  cue / Data
//

import CoreLocation
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
            isDefault: calendar.calendarIdentifier == defaultListID,
            isReadOnly: !calendar.allowsContentModifications
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
            priority: toPriority(reminder.priority),
            locationAlarm: representedLocationAlarm(in: reminder.alarms)?.domain,
            listID: reminder.calendar.calendarIdentifier
        )
    }

    // MARK: - 편집 적용 (도메인 → EKReminder)

    /// `changes`를 EKReminder에 쓴다(리스트=calendar 교체는 저장소 조회가 필요해 호출부 몫).
    /// 도메인이 EventKit보다 거칠게 표현하는 값(반복 세부·우선순위 정수·위치 알람 세부)은
    /// **실제로 바뀌었을 때만** 재기록해, 미리알림 앱에서 만든 원본을 깎지 않는다.
    static func apply(_ changes: ReminderChanges, to reminder: EKReminder) {
        // 알람 판정의 기준은 **바꾸기 전** 마감 시각 — 먼저 읽어 둔다.
        let previousDue = timedDueDate(reminder.dueDateComponents)
        reminder.title = changes.title
        reminder.notes = changes.notes

        let effectiveRecurrence = changes.dueDate != nil ? changes.recurrence : nil
        if !isEquivalentRecurrence(reminder.recurrenceRules?.first, to: effectiveRecurrence) {
            (reminder.recurrenceRules ?? []).forEach(reminder.removeRecurrenceRule)
            if let rule = toEKRecurrenceRule(effectiveRecurrence) {
                reminder.addRecurrenceRule(rule)
            }
        }

        if toPriority(reminder.priority) != changes.priority {
            reminder.priority = toEKPriority(changes.priority)
        }

        // 마감 알람은 cue가 단 것(=이전 마감 시각의 절대 알람)만 떼고 새 마감 시각으로 다시 단다.
        for alarm in (reminder.alarms ?? []) where isCueManagedDueAlarm(alarm, previousDue: previousDue) {
            reminder.removeAlarm(alarm)
        }
        if let dueDate = changes.dueDate {
            // 시간이 없으면 [년·월·일]만 — EventKit은 이를 "종일" 마감으로 본다.
            let fields: Set<Calendar.Component> = changes.includesTime
                ? [.year, .month, .day, .hour, .minute]
                : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: dueDate)
            // 마감일만으로는 알림이 울리지 않는다 — 시간이 있으면 알람을 함께 단다.
            if changes.includesTime {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        } else {
            reminder.dueDateComponents = nil
        }

        let represented = representedLocationAlarm(in: reminder.alarms)
        if represented?.domain != changes.locationAlarm {
            if let alarm = represented?.alarm { reminder.removeAlarm(alarm) }
            if let locationAlarm = changes.locationAlarm {
                reminder.addAlarm(toEKLocationAlarm(locationAlarm))
            }
        }
    }

    // MARK: - 이 미리 알림만 삭제

    /// "이 미리 알림만 삭제" — 같은 항목의 마감을 다음 회차 날로 옮기고 절대 시각 알람도 같은 만큼 민다
    /// (완료 기록을 남기지 않는다, 미리 알림 앱과 같다). 다음 회차가 없으면(마지막 회차) 그대로 두고 false.
    static func moveDueToNextOccurrence(of reminder: EKReminder, rule: RecurrenceRule, now: Date) -> Bool {
        guard var components = reminder.dueDateComponents else { return false }
        // 마감 자신의 달력·시간대로 센다 — 기기 시간대·달력과 달라도 날짜가 어긋나지 않게.
        var calendar = components.calendar ?? .current
        if let timeZone = components.timeZone { calendar.timeZone = timeZone }
        guard let due = calendar.date(from: components),
              let next = rule.nextOccurrence(after: due, now: now, calendar: calendar)
        else { return false }
        let day = calendar.dateComponents([.year, .month, .day], from: next)
        components.year = day.year
        components.month = day.month
        components.day = day.day
        reminder.dueDateComponents = components
        // 상대 오프셋 알람은 마감을 따라가고, 위치 알람은 시각이 없다.
        let shift = next.timeIntervalSince(due)
        for alarm in reminder.alarms ?? [] where alarm.structuredLocation == nil {
            if let date = alarm.absoluteDate {
                alarm.absoluteDate = date.addingTimeInterval(shift)
            }
        }
        return true
    }

    // MARK: - 알람

    /// cue가 관리하는 마감 알람인지 — **이전 마감 시각과 같은 시각의 절대 알람(위치 없음)**만.
    /// 다른 시각의 절대 알람·상대 오프셋·위치 알람은 사용자가 미리알림 앱에서 단 것일 수 있어
    /// 편집 저장 시 보존한다 — 일정 편집의 `.custom` 알림 보존과 같은 계약.
    /// 분 단위로 비교한다: 마감 컴포넌트는 분까지만 남지만 알람은 저장 당시 초까지 들고 있다.
    /// `previousDue`가 nil(마감 없음·종일)이면 cue가 단 알람이 없으므로 아무것도 해당하지 않는다.
    static func isCueManagedDueAlarm(_ alarm: EKAlarm, previousDue: Date?) -> Bool {
        guard let previousDue, let date = alarm.absoluteDate, alarm.structuredLocation == nil else {
            return false
        }
        return Calendar.current.compare(date, to: previousDue, toGranularity: .minute) == .orderedSame
    }

    /// 시각이 지정된 마감 컴포넌트 → Date. 종일(시 없음)·마감 없음이면 nil.
    /// 컴포넌트에 calendar가 없으면 `.date`가 nil이라 현재 달력으로 보정한다.
    static func timedDueDate(_ components: DateComponents?) -> Date? {
        guard let components, components.hour != nil else { return nil }
        return components.date ?? Calendar.current.date(from: components)
    }

    /// 도메인이 표현하는 위치 알람 — 위치·도착/출발·좌표를 모두 갖춘 첫 알람.
    /// 표현 못 하는 위치 알람(좌표 없음·proximity 없음)은 여기서 빠져 저장 시 그대로 보존된다.
    static func representedLocationAlarm(
        in alarms: [EKAlarm]?
    ) -> (alarm: EKAlarm, domain: ReminderLocationAlarm)? {
        for alarm in alarms ?? [] {
            if let domain = toLocationAlarm(alarm) { return (alarm, domain) }
        }
        return nil
    }

    /// `EKAlarm`(위치 기반) → 도메인. 이름과 주소는 Apple 캘린더처럼 title의 첫 줄·나머지로 나눈다
    /// (`EKStructuredLocation`에 주소 필드가 따로 없다). 반경 0은 시스템 기본(nil).
    static func toLocationAlarm(_ alarm: EKAlarm) -> ReminderLocationAlarm? {
        guard let location = alarm.structuredLocation, let geo = location.geoLocation else { return nil }
        let proximity: ReminderLocationAlarm.Proximity
        switch alarm.proximity {
        case .enter: proximity = .arriving
        case .leave: proximity = .leaving
        default: return nil
        }
        let lines = (location.title ?? "").split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let address = lines.count > 1 ? String(lines[1]) : nil
        return ReminderLocationAlarm(
            title: String(lines.first ?? ""),
            address: address?.isEmpty == true ? nil : address,
            latitude: geo.coordinate.latitude,
            longitude: geo.coordinate.longitude,
            radius: location.radius > 0 ? location.radius : nil,
            proximity: proximity
        )
    }

    /// 도메인 위치 알람 → `EKAlarm`. 상대 오프셋 0 + structuredLocation + proximity가
    /// 미리알림 앱의 위치 알람과 같은 형태다.
    static func toEKLocationAlarm(_ locationAlarm: ReminderLocationAlarm) -> EKAlarm {
        // 빈 주소는 주소 없음 — "이름\n"으로 쓰면 다시 읽을 때 nil이 돼 매번 변경으로 판정된다.
        let address = locationAlarm.address.flatMap { $0.isEmpty ? nil : $0 }
        let title = address.map { "\(locationAlarm.title)\n\($0)" } ?? locationAlarm.title
        let location = EKStructuredLocation(title: title)
        location.geoLocation = CLLocation(latitude: locationAlarm.latitude, longitude: locationAlarm.longitude)
        location.radius = locationAlarm.radius ?? 0
        let alarm = EKAlarm(relativeOffset: 0)
        alarm.structuredLocation = location
        alarm.proximity = locationAlarm.proximity == .arriving ? .enter : .leave
        return alarm
    }

    // MARK: - 우선순위

    /// EventKit 정수(0~9) → 4단계. 0 없음, 1~4 높음, 5 중간, 6~9 낮음(RFC 5545·미리알림 앱 기준).
    static func toPriority(_ value: Int) -> ReminderPriority {
        switch value {
        case 1...4: .high
        case 5: .medium
        case 6...9: .low
        default: .none
        }
    }

    /// 4단계 → EventKit 정수. 미리알림 앱이 쓰는 대표값(높음 1, 중간 5, 낮음 9).
    /// 저장 경로는 단계가 바뀐 경우에만 이 값을 쓴다 — 3 같은 세분값을 1로 깎지 않기 위해.
    static func toEKPriority(_ priority: ReminderPriority) -> Int {
        switch priority {
        case .none: 0
        case .high: 1
        case .medium: 5
        case .low: 9
        }
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
        // 단순화해도 종료일은 지키고, 단순화 표시를 남긴다(회차 계산 금지 — RecurrenceRule.isApproximate).
        let fallback = RecurrenceRule(
            frequency: frequency, interval: rule.interval,
            endDate: rule.recurrenceEnd?.endDate, isApproximate: true
        )

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
