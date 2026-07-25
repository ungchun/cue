//
//  EventEditDraft.swift
//  cue / Presentation
//

import EventKit
import Foundation

/// 자체 이벤트 편집 시트(EventDetailSheet)의 편집 상태 — EKEvent 읽기/쓰기와 시간·반복·알림
/// 로직을 뷰 밖으로 꺼내 단위 테스트 가능하게 둔다. 뷰는 이 드래프트만 바인딩한다.
///
/// EventKit이 서드파티에 공개하지 않는 초대받은 사람·이동 시간은 다루지 않는다.
/// 프리셋 밖의 반복 규칙·알림(요일 지정 반복, -7분 알림 등)은 `.custom`으로 표시만 하고
/// 저장 시 **기존 값을 보존**한다 — 우리 폼이 못 그리는 고급 설정을 파괴하지 않기 위해.
struct EventEditDraft: Equatable {
    var title: String
    var location: String
    var isAllDay: Bool
    private(set) var start: Date
    private(set) var end: Date
    var recurrence: Recurrence
    /// 반복 종료 — `.never` 또는 특정 날짜. `.foreign` 규칙에선 무시(원본 보존).
    var recurrenceEnd: RecurrenceEnd
    var alarm: Alarm
    var urlString: String
    var notes: String
    /// 선택한 캘린더 식별자 — 뷰가 EKCalendar로 해석해 apply 시 주입한다.
    var calendarID: String?

    // MARK: - 생성

    /// 신규 이벤트 기본값 — 다음 정시부터 1시간(Apple 캘린더 신규 시트와 동일).
    static func newEvent(now: Date, calendar: Calendar = .current) -> EventEditDraft {
        let hourFloor = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let start = hourFloor == now ? now : calendar.date(byAdding: .hour, value: 1, to: hourFloor) ?? now
        return EventEditDraft(
            title: "", location: "", isAllDay: false,
            start: start, end: start.addingTimeInterval(3600),
            recurrence: .none, recurrenceEnd: .never,
            alarm: .none, urlString: "", notes: "", calendarID: nil
        )
    }

    /// 기존 이벤트 스냅샷 — 편집 모드 초기값.
    init(event: EKEvent) {
        title = event.title ?? ""
        location = event.location ?? ""
        isAllDay = event.isAllDay
        start = event.startDate
        end = event.endDate
        recurrence = Recurrence(rules: event.recurrenceRules)
        recurrenceEnd = RecurrenceEnd(rules: event.recurrenceRules)
        alarm = Alarm(alarms: event.alarms)
        urlString = event.url?.absoluteString ?? ""
        notes = event.notes ?? ""
        calendarID = event.calendar?.calendarIdentifier
    }

    private init(
        title: String, location: String, isAllDay: Bool, start: Date, end: Date,
        recurrence: Recurrence, recurrenceEnd: RecurrenceEnd,
        alarm: Alarm, urlString: String, notes: String, calendarID: String?
    ) {
        self.title = title
        self.location = location
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.recurrence = recurrence
        self.recurrenceEnd = recurrenceEnd
        self.alarm = alarm
        self.urlString = urlString
        self.notes = notes
        self.calendarID = calendarID
    }

    // MARK: - 시간 로직

    /// 시작 이동 — 기존 지속시간을 유지한 채 종료가 따라간다(Apple 캘린더와 동일).
    mutating func setStart(_ newStart: Date) {
        let duration = end.timeIntervalSince(start)
        start = newStart
        end = newStart.addingTimeInterval(duration)
    }

    /// 종료 이동 — 시작 이전으로는 못 내린다(시작 시각으로 클램프).
    mutating func setEnd(_ newEnd: Date) {
        end = max(newEnd, start)
    }

    // MARK: - EKEvent 쓰기

    /// 드래프트를 이벤트에 반영한다. 빈 문자열 필드는 nil로 정리(EventKit 관례).
    /// `.custom` 반복·알림은 기존 값을 그대로 둔다 — 보존 계약(위 타입 주석 참고).
    func apply(to event: EKEvent) {
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.location = Self.nilIfEmpty(location)
        event.notes = Self.nilIfEmpty(notes)
        event.url = Self.nilIfEmpty(urlString).flatMap(URL.init(string:))
        event.isAllDay = isAllDay
        event.startDate = start
        event.endDate = end

        if recurrence != .foreign {
            (event.recurrenceRules ?? []).forEach(event.removeRecurrenceRule)
            if let rule = recurrence.rule(endingOn: recurrenceEnd) { event.addRecurrenceRule(rule) }
        }
        if alarm != .custom {
            (event.alarms ?? []).forEach(event.removeAlarm)
            if let offset = alarm.relativeOffset { event.addAlarm(EKAlarm(relativeOffset: offset)) }
        }
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - 반복 옵션

    /// 반복 종료 — Apple 캘린더의 "반복 종료: 안 함 / 날짜"와 동일.
    /// (횟수 종료는 EventKit엔 있지만 Apple 편집 UI에 없어 `.foreign` 보존으로만 다룬다.)
    enum RecurrenceEnd: Hashable {
        case never
        case onDate(Date)

        init(rules: [EKRecurrenceRule]?) {
            if let date = rules?.first?.recurrenceEnd?.endDate {
                self = .onDate(date)
            } else {
                self = .never
            }
        }

        var recurrenceEnd: EKRecurrenceEnd? {
            switch self {
            case .never: nil
            case .onDate(let date): EKRecurrenceEnd(end: date)
            }
        }
    }

    /// 반복 옵션 — Apple 캘린더 프리셋 + 사용자 설정(빈도·간격·요일/일자/월 지정).
    /// 우리 편집기로도 표현 못 하는 규칙(횟수 종료, setPositions, 복수 규칙 등)은
    /// `.foreign` — 표시만 하고 저장 시 원본을 보존한다.
    enum Recurrence: Hashable {
        case none, daily, weekly, biweekly, monthly, yearly
        case custom(CustomRule)
        case foreign

        /// 선택 목록에 노출하는 프리셋.
        static var presets: [Recurrence] { [.none, .daily, .weekly, .biweekly, .monthly, .yearly] }

        var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }

        /// 사용자화가 프리셋과 동치(추가 지정 없는 매일 1·매주 1·매주 2·매월 1·매년 1)면
        /// 프리셋으로 접는다 — 사용자화 화면에서 그대로 나왔을 때 메뉴가 매일/매주… 로 돌아가게.
        var normalized: Recurrence {
            guard case .custom(let rule) = self,
                  rule.weekdays.isEmpty, rule.monthDays.isEmpty,
                  rule.months.isEmpty, rule.ordinal == nil
            else { return self }
            switch (rule.frequency, rule.interval) {
            case (.daily, 1): return .daily
            case (.weekly, 1): return .weekly
            case (.weekly, 2): return .biweekly
            case (.monthly, 1): return .monthly
            case (.yearly, 1): return .yearly
            default: return self
            }
        }

        init(rules: [EKRecurrenceRule]?) {
            guard let rule = rules?.first else {
                self = .none
                return
            }
            guard let custom = CustomRule(rules: rules) else {
                self = .foreign
                return
            }
            // 부가 지정 없는 순수 빈도+간격이면 프리셋으로 승격.
            let isPlain = custom.weekdays.isEmpty && custom.monthDays.isEmpty
                && custom.months.isEmpty && custom.ordinal == nil
            guard isPlain else {
                self = .custom(custom)
                return
            }
            switch (rule.frequency, rule.interval) {
            case (.daily, 1): self = .daily
            case (.weekly, 1): self = .weekly
            case (.weekly, 2): self = .biweekly
            case (.monthly, 1): self = .monthly
            case (.yearly, 1): self = .yearly
            default: self = .custom(custom)
            }
        }

        /// 이 옵션의 EKRecurrenceRule(반복 종료 포함). `.none`/`.foreign`은 nil —
        /// foreign은 "기존 규칙을 건드리지 말라"는 신호(apply가 분기).
        func rule(endingOn end: RecurrenceEnd) -> EKRecurrenceRule? {
            let make = { EKRecurrenceRule(recurrenceWith: $0, interval: $1, end: end.recurrenceEnd) }
            switch self {
            case .none, .foreign: return nil
            case .daily: return make(.daily, 1)
            case .weekly: return make(.weekly, 1)
            case .biweekly: return make(.weekly, 2)
            case .monthly: return make(.monthly, 1)
            case .yearly: return make(.yearly, 1)
            case .custom(let custom): return custom.rule(end: end.recurrenceEnd)
            }
        }
    }

    /// 사용자 설정 반복 — Apple 캘린더 "사용자화"의 부분집합: 빈도·간격에 더해
    /// 매주는 요일, 매월은 일자, 매년은 월을 지정할 수 있다.
    struct CustomRule: Hashable {
        enum Frequency: Hashable, CaseIterable {
            case daily, weekly, monthly, yearly

            var ekFrequency: EKRecurrenceFrequency {
                switch self {
                case .daily: .daily
                case .weekly: .weekly
                case .monthly: .monthly
                case .yearly: .yearly
                }
            }
        }

        var frequency: Frequency
        var interval: Int
        /// 매주 반복의 요일(EKWeekday rawValue 1=일 … 7=토). 비면 시작일 요일을 따른다.
        var weekdays: Set<Int> = []
        /// 매월 반복의 일자(1…31). 비면 시작일 일자를 따른다. `ordinal` 지정 시 무시.
        var monthDays: Set<Int> = []
        /// 매년 반복의 월(1…12). 비면 시작일 월을 따른다.
        var months: Set<Int> = []
        /// 서수 요일 지정(Apple "다음 순서로") — 1…5 = 첫째…다섯째, -1 = 마지막.
        /// 매월·매년에서만 의미. `ordinalWeekday`와 항상 짝으로 쓴다.
        var ordinal: Int?
        /// 서수 요일의 요일(EKWeekday rawValue).
        var ordinalWeekday: Int?

        /// 표현 가능한 규칙이면 파싱, 아니면 nil(→ `.foreign`).
        /// 불가 조건: 복수 규칙 · 횟수 종료 · 주차·연중일 지정 · 빈도와 안 맞는 지정 ·
        /// 음수 일자("마지막 날") · 복수 setPositions.
        init?(rules: [EKRecurrenceRule]?) {
            guard let rules, rules.count == 1, let rule = rules.first else { return nil }
            guard rule.recurrenceEnd?.occurrenceCount ?? 0 == 0,
                  rule.weeksOfTheYear == nil, rule.daysOfTheYear == nil
            else { return nil }

            let frequency: Frequency
            switch rule.frequency {
            case .daily: frequency = .daily
            case .weekly: frequency = .weekly
            case .monthly: frequency = .monthly
            case .yearly: frequency = .yearly
            @unknown default: return nil
            }

            var weekdays: Set<Int> = []
            var ordinal: Int?
            var ordinalWeekday: Int?
            if let positions = rule.setPositions {
                // setPositions 인코딩 — "매월/매년 N째 X요일". 단일 서수 + 단일 요일만 지원.
                guard positions.count == 1, frequency == .monthly || frequency == .yearly,
                      let days = rule.daysOfTheWeek, days.count == 1, days[0].weekNumber == 0,
                      rule.daysOfTheMonth == nil
                else { return nil }
                ordinal = positions[0].intValue
                ordinalWeekday = days[0].dayOfTheWeek.rawValue
            } else if let days = rule.daysOfTheWeek {
                if frequency == .weekly, days.allSatisfy({ $0.weekNumber == 0 }) {
                    weekdays = Set(days.map { $0.dayOfTheWeek.rawValue })
                } else if frequency == .monthly, days.count == 1, days[0].weekNumber != 0,
                          rule.daysOfTheMonth == nil {
                    // weekNumber 인코딩 — 같은 의미의 또 다른 표현("둘째 화요일").
                    ordinal = days[0].weekNumber
                    ordinalWeekday = days[0].dayOfTheWeek.rawValue
                } else {
                    return nil
                }
            }
            var monthDays: Set<Int> = []
            if let days = rule.daysOfTheMonth {
                guard frequency == .monthly, days.allSatisfy({ $0.intValue >= 1 }) else { return nil }
                monthDays = Set(days.map(\.intValue))
            }
            var months: Set<Int> = []
            if let list = rule.monthsOfTheYear {
                guard frequency == .yearly else { return nil }
                months = Set(list.map(\.intValue))
            }

            self.frequency = frequency
            self.interval = max(1, rule.interval)
            self.weekdays = weekdays
            self.monthDays = monthDays
            self.months = months
            self.ordinal = ordinal
            self.ordinalWeekday = ordinalWeekday
        }

        init(frequency: Frequency, interval: Int,
             weekdays: Set<Int> = [], monthDays: Set<Int> = [], months: Set<Int> = [],
             ordinal: Int? = nil, ordinalWeekday: Int? = nil) {
            self.frequency = frequency
            self.interval = interval
            self.weekdays = weekdays
            self.monthDays = monthDays
            self.months = months
            self.ordinal = ordinal
            self.ordinalWeekday = ordinalWeekday
        }

        func rule(end: EKRecurrenceEnd?) -> EKRecurrenceRule {
            // 서수 요일("N째 X요일")은 setPositions로 인코딩 — 매월·매년 공통이고
            // Apple 캘린더가 쓰는 방식과 같다. 이때 일자 지정(monthDays)은 무시.
            let usesOrdinal = (frequency == .monthly || frequency == .yearly)
                && ordinal != nil && ordinalWeekday != nil
            let ordinalDays = ordinalWeekday
                .flatMap(EKWeekday.init(rawValue:))
                .map { [EKRecurrenceDayOfWeek($0)] }
            return EKRecurrenceRule(
                recurrenceWith: frequency.ekFrequency,
                interval: interval,
                daysOfTheWeek: usesOrdinal
                    ? ordinalDays
                    : (frequency == .weekly && !weekdays.isEmpty
                        ? weekdays.sorted().compactMap { EKWeekday(rawValue: $0).map { EKRecurrenceDayOfWeek($0) } }
                        : nil),
                daysOfTheMonth: !usesOrdinal && frequency == .monthly && !monthDays.isEmpty
                    ? monthDays.sorted().map(NSNumber.init(value:))
                    : nil,
                monthsOfTheYear: frequency == .yearly && !months.isEmpty
                    ? months.sorted().map(NSNumber.init(value:))
                    : nil,
                weeksOfTheYear: nil, daysOfTheYear: nil,
                setPositions: usesOrdinal ? ordinal.map { [NSNumber(value: $0)] } : nil,
                end: end
            )
        }
    }

    // MARK: - 알림 옵션

    /// Apple 캘린더 알림 프리셋(상대 오프셋) — 그 밖의 값은 `.custom`(표시·보존 전용).
    enum Alarm: Hashable {
        case none
        case atTime                 // 이벤트 당시(오프셋 0)
        case minutesBefore(Int)     // 프리셋 분 단위만(presetMinutes)
        case custom

        /// 선택 메뉴에 노출하는 분 프리셋 — Apple 캘린더와 동일 구성.
        static let presetMinutes = [5, 10, 15, 30, 60, 120, 1_440, 2_880, 10_080]
        static var presets: [Alarm] { [.none, .atTime] + presetMinutes.map(Alarm.minutesBefore) }

        init(alarms: [EKAlarm]?) {
            // 프리셋은 단일 상대 알림일 때만 — 절대시각 알림·복수 알림은 custom 보존.
            guard let alarms, alarms.count == 1, let first = alarms.first,
                  first.absoluteDate == nil else {
                self = alarms?.isEmpty == false ? .custom : .none
                return
            }
            let offset = first.relativeOffset
            if offset == 0 {
                self = .atTime
            } else if offset < 0, offset.truncatingRemainder(dividingBy: 60) == 0,
                      Self.presetMinutes.contains(Int(-offset) / 60) {
                self = .minutesBefore(Int(-offset) / 60)
            } else {
                self = .custom
            }
        }

        /// 이벤트 시작 기준 상대 오프셋(초). `.none`/`.custom`은 nil.
        var relativeOffset: TimeInterval? {
            switch self {
            case .none, .custom: return nil
            case .atTime: return 0
            case .minutesBefore(let minutes): return TimeInterval(-minutes * 60)
            }
        }
    }
}
