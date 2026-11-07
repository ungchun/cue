//
//  EventEditDraft.swift
//  cue / Presentation
//

import CoreLocation
import EventKit
import Foundation

/// 자체 이벤트 편집 시트(EventDetailSheet)의 편집 상태 — EKEvent 읽기/쓰기와 시간·반복·알림
/// 로직을 뷰 밖으로 꺼내 단위 테스트 가능하게 둔다. 뷰는 이 드래프트만 바인딩한다.
///
/// EventKit이 서드파티에 공개하지 않는 이동 시간·초대받은 사람 편집은 다루지 않는다.
/// 프리셋 밖의 반복 규칙·알림(요일 지정 반복, -7분 알림 등)은 `.custom`으로 표시만 하고
/// 저장 시 **기존 값을 보존**한다 — 우리 폼이 못 그리는 고급 설정을 파괴하지 않기 위해.
struct EventEditDraft: Equatable {
    var title: String
    /// 위치 — 지도 검색으로 고른 구조화 위치(제목·주소·좌표) 또는 직접 입력 문자열. nil = 없음.
    var location: Location?
    var isAllDay: Bool {
        // 종일 ↔ 시간 지정은 알림 프리셋 체계가 다르다 — 새 체계에 없는 프리셋은 "없음"으로.
        didSet {
            guard isAllDay != oldValue else { return }
            firstAlarm = firstAlarm.fits(isAllDay: isAllDay) ? firstAlarm : .none
            secondAlarm = secondAlarm.fits(isAllDay: isAllDay) ? secondAlarm : .none
        }
    }
    private(set) var start: Date
    private(set) var end: Date
    /// 시간 지정 이벤트의 시간대. nil = 유동(floating — 기기 시간대를 따름). 종일 이벤트에선 무시.
    private(set) var timeZone: TimeZone?
    var recurrence: Recurrence
    /// 반복 종료 — `.never` 또는 특정 날짜. `.foreign` 규칙에선 무시(원본 보존).
    var recurrenceEnd: RecurrenceEnd
    /// 알림 두 칸 — Apple 캘린더의 "알림 / 두 번째 알림". 첫 칸이 없음이면 두 번째는 무시.
    var firstAlarm: Alarm
    var secondAlarm: Alarm
    /// 다음으로 표시(바쁨/한가함…). `.notSupported` = 건드리지 않음(EventKit 기본값 유지).
    var availability: EKEventAvailability
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
            title: "", location: nil, isAllDay: false,
            start: start, end: start.addingTimeInterval(3600),
            timeZone: calendar.timeZone,
            recurrence: .none, recurrenceEnd: .never,
            firstAlarm: .none, secondAlarm: .none, availability: .notSupported,
            urlString: "", notes: "", calendarID: nil
        )
    }

    /// 기존 이벤트 스냅샷 — 편집 모드 초기값.
    init(event: EKEvent) {
        title = event.title ?? ""
        location = Location(event: event)
        isAllDay = event.isAllDay
        // startDate/endDate는 암시적 언래핑(Date!) — 저장소에서 온 이벤트는 항상 있지만,
        // 방어적으로 폴백해 손상 데이터에서도 크래시하지 않게 한다.
        let fallbackStart = event.startDate ?? Date()
        start = fallbackStart
        end = event.endDate ?? fallbackStart.addingTimeInterval(3600)
        timeZone = event.timeZone
        recurrence = Recurrence(rules: event.recurrenceRules)
        recurrenceEnd = RecurrenceEnd(rules: event.recurrenceRules)
        (firstAlarm, secondAlarm) = Alarm.slots(from: event.alarms, isAllDay: event.isAllDay, eventStart: fallbackStart)
        availability = event.availability
        urlString = event.url?.absoluteString ?? ""
        notes = event.notes ?? ""
        calendarID = event.calendar?.calendarIdentifier
    }

    private init(
        title: String, location: Location?, isAllDay: Bool, start: Date, end: Date,
        timeZone: TimeZone?, recurrence: Recurrence, recurrenceEnd: RecurrenceEnd,
        firstAlarm: Alarm, secondAlarm: Alarm, availability: EKEventAvailability,
        urlString: String, notes: String, calendarID: String?
    ) {
        self.title = title
        self.location = location
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.timeZone = timeZone
        self.recurrence = recurrence
        self.recurrenceEnd = recurrenceEnd
        self.firstAlarm = firstAlarm
        self.secondAlarm = secondAlarm
        self.availability = availability
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

    /// 시간대 변경 — 벽시계 시각(10:00)은 그대로 두고 새 시간대의 10:00으로 옮긴다
    /// (Apple 캘린더와 동일). nil(유동)은 `deviceZone` 기준으로 해석한다.
    mutating func setTimeZone(_ newZone: TimeZone?, deviceZone: TimeZone = .current) {
        let from = timeZone ?? deviceZone
        let to = newZone ?? deviceZone
        start = Self.wallClock(start, from: from, to: to)
        end = Self.wallClock(end, from: from, to: to)
        timeZone = newZone
    }

    private static func wallClock(_ date: Date, from: TimeZone, to: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = from
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        calendar.timeZone = to
        return calendar.date(from: components) ?? date
    }

    // MARK: - EKEvent 쓰기

    /// 드래프트를 이벤트에 반영한다. 빈 문자열 필드는 nil로 정리(EventKit 관례).
    /// `.custom` 반복·알림은 기존 값을 그대로 둔다 — 보존 계약(위 타입 주석 참고).
    func apply(to event: EKEvent) {
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let location {
            // 구조화 위치(제목\n주소 + 좌표)로 저장 — Apple 캘린더와 같은 표현.
            let structured = EKStructuredLocation(title: location.displayText)
            if let latitude = location.latitude, let longitude = location.longitude {
                structured.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
            }
            event.structuredLocation = structured
            event.location = location.displayText
        } else {
            event.structuredLocation = nil
            event.location = nil
        }
        event.notes = Self.nilIfEmpty(notes)
        event.url = Self.nilIfEmpty(urlString).flatMap(URL.init(string:))
        event.isAllDay = isAllDay
        // 시작/종료는 절대 시각이라 시간대는 표시·반복 계산 기준일 뿐이다(setTimeZone이 벽시계를
        // 이미 옮겨 둠). 종일 이벤트는 시간대가 의미 없어 원본 그대로 둔다.
        if !isAllDay { event.timeZone = timeZone }
        event.startDate = start
        event.endDate = end
        if availability != .notSupported { event.availability = availability }

        if recurrence != .foreign {
            (event.recurrenceRules ?? []).forEach(event.removeRecurrenceRule)
            if let rule = recurrence.rule(endingOn: recurrenceEnd) { event.addRecurrenceRule(rule) }
        }
        applyAlarms(to: event)
    }

    /// 알림 두 칸 반영. 두 칸 모두 `.custom`(3개 이상·위치 알림 등)이면 원본을 통째로 두고,
    /// 한 칸만 `.custom`이면 그 자리의 원본 알림을 복사해 남긴다 — 보존 계약.
    private func applyAlarms(to event: EKEvent) {
        if firstAlarm == .custom, secondAlarm == .custom { return }
        let original = Alarm.ordered(event.alarms ?? [], eventStart: event.startDate ?? start)
        let slots = firstAlarm == .none ? [] : [firstAlarm, secondAlarm]
        let next = slots.enumerated().compactMap { index, slot -> EKAlarm? in
            guard slot == .custom else { return slot.makeEKAlarm() }
            return index < original.count ? original[index].copy() as? EKAlarm : nil
        }
        original.forEach(event.removeAlarm)
        next.forEach(event.addAlarm)
    }

    /// 캘린더가 지원하는 "다음으로 표시" 선택지 — 지원 안 하면 빈 배열(행 숨김).
    static func availabilityOptions(for supported: EKCalendarEventAvailabilityMask) -> [EKEventAvailability] {
        let all: [(EKCalendarEventAvailabilityMask, EKEventAvailability)] = [
            (.busy, .busy), (.free, .free), (.tentative, .tentative), (.unavailable, .unavailable),
        ]
        return all.filter { supported.contains($0.0) }.map { $0.1 }
    }

    private static func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - 위치

    /// 이벤트 위치 — 제목 + (선택) 주소·좌표. `location` 문자열은 "제목\n주소"로 직렬화되고
    /// 좌표는 `EKStructuredLocation.geoLocation`에 실린다(Apple 캘린더와 같은 표현).
    struct Location: Hashable {
        var title: String
        var address: String?
        var latitude: Double?
        var longitude: Double?

        init(title: String, address: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
            self.title = title
            self.address = address
            self.latitude = latitude
            self.longitude = longitude
        }

        /// 기존 이벤트에서 복원 — location 문자열 첫 줄=제목, 나머지=주소, 좌표는 구조화 위치.
        init?(event: EKEvent) {
            guard let raw = event.location, !raw.isEmpty else { return nil }
            let lines = raw.split(separator: "\n", maxSplits: 1).map(String.init)
            title = lines.first ?? raw
            address = lines.count > 1 ? lines[1] : nil
            if let geo = event.structuredLocation?.geoLocation {
                latitude = geo.coordinate.latitude
                longitude = geo.coordinate.longitude
            }
        }

        /// "제목\n주소" — EKEvent.location 문자열 및 행 표시용.
        var displayText: String {
            guard let address, !address.isEmpty else { return title }
            return "\(title)\n\(address)"
        }
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
}

// MARK: - 할일(Reminder) 도메인 브리지

/// 할일 세부사항 시트가 같은 반복 편집 UI(RepeatOptionScreen 등)를 재사용하기 위한
/// 변환 — 도메인 `RecurrenceRule`(EventKit 무지) ↔ 편집 UI 모델.
extension EventEditDraft.Recurrence {
    /// 도메인 규칙 → UI 모델. 부가 지정 없는 프리셋 동치는 프리셋으로 접는다.
    init(reminderRule rule: RecurrenceRule?) {
        guard let rule else {
            self = .none
            return
        }
        let custom = EventEditDraft.CustomRule(
            frequency: .init(domain: rule.frequency),
            interval: rule.interval,
            weekdays: rule.weekdays, monthDays: rule.monthDays, months: rule.months,
            ordinal: rule.ordinal, ordinalWeekday: rule.ordinalWeekday
        )
        let isPlain = custom.weekdays.isEmpty && custom.monthDays.isEmpty
            && custom.months.isEmpty && custom.ordinal == nil
        guard isPlain else {
            self = .custom(custom)
            return
        }
        switch (custom.frequency, custom.interval) {
        case (.daily, 1): self = .daily
        case (.weekly, 1): self = .weekly
        case (.weekly, 2): self = .biweekly
        case (.monthly, 1): self = .monthly
        case (.yearly, 1): self = .yearly
        default: self = .custom(custom)
        }
    }

    /// UI 모델 + 반복 종료 → 도메인 규칙. 안 함(none)·foreign은 nil.
    func reminderRule(endingOn end: EventEditDraft.RecurrenceEnd) -> RecurrenceRule? {
        let endDate: Date? = {
            if case .onDate(let date) = end { return date }
            return nil
        }()
        switch self {
        case .none, .foreign: return nil
        case .daily: return RecurrenceRule(frequency: .daily, endDate: endDate)
        case .weekly: return RecurrenceRule(frequency: .weekly, endDate: endDate)
        case .biweekly: return RecurrenceRule(frequency: .weekly, interval: 2, endDate: endDate)
        case .monthly: return RecurrenceRule(frequency: .monthly, endDate: endDate)
        case .yearly: return RecurrenceRule(frequency: .yearly, endDate: endDate)
        case .custom(let rule):
            return RecurrenceRule(
                frequency: rule.frequency.domain,
                interval: rule.interval,
                weekdays: rule.weekdays, monthDays: rule.monthDays, months: rule.months,
                ordinal: rule.ordinal, ordinalWeekday: rule.ordinalWeekday,
                endDate: endDate
            )
        }
    }
}

extension EventEditDraft.RecurrenceEnd {
    /// 도메인 규칙의 endDate → UI의 반복 종료.
    init(reminderRule rule: RecurrenceRule?) {
        if let date = rule?.endDate {
            self = .onDate(date)
        } else {
            self = .never
        }
    }
}

extension EventEditDraft.CustomRule.Frequency {
    init(domain frequency: RecurrenceFrequency) {
        switch frequency {
        case .daily: self = .daily
        case .weekly: self = .weekly
        case .monthly: self = .monthly
        case .yearly: self = .yearly
        }
    }

    var domain: RecurrenceFrequency {
        switch self {
        case .daily: .daily
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }
}
