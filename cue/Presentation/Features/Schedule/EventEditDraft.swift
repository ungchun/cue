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
            recurrence: .none, alarm: .none, urlString: "", notes: "", calendarID: nil
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
        alarm = Alarm(alarms: event.alarms)
        urlString = event.url?.absoluteString ?? ""
        notes = event.notes ?? ""
        calendarID = event.calendar?.calendarIdentifier
    }

    private init(
        title: String, location: String, isAllDay: Bool, start: Date, end: Date,
        recurrence: Recurrence, alarm: Alarm, urlString: String, notes: String, calendarID: String?
    ) {
        self.title = title
        self.location = location
        self.isAllDay = isAllDay
        self.start = start
        self.end = end
        self.recurrence = recurrence
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

        if recurrence != .custom {
            (event.recurrenceRules ?? []).forEach(event.removeRecurrenceRule)
            if let rule = recurrence.rule() { event.addRecurrenceRule(rule) }
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

    /// Apple 캘린더 반복 프리셋 — 그 밖의 규칙은 `.custom`(표시·보존 전용).
    enum Recurrence: Hashable {
        case none, daily, weekly, biweekly, monthly, yearly, custom

        /// 선택 메뉴에 노출하는 프리셋 — custom은 기존 규칙 표시용이라 제외.
        static var presets: [Recurrence] { [.none, .daily, .weekly, .biweekly, .monthly, .yearly] }

        init(rules: [EKRecurrenceRule]?) {
            guard let rule = rules?.first else {
                self = .none
                return
            }
            // 프리셋은 단일 규칙 + 부가 조건 없음(요일/일자 지정 없음)일 때만.
            let isPlain = rules?.count == 1
                && rule.daysOfTheWeek == nil && rule.daysOfTheMonth == nil
                && rule.monthsOfTheYear == nil && rule.setPositions == nil
            guard isPlain else {
                self = .custom
                return
            }
            switch (rule.frequency, rule.interval) {
            case (.daily, 1): self = .daily
            case (.weekly, 1): self = .weekly
            case (.weekly, 2): self = .biweekly
            case (.monthly, 1): self = .monthly
            case (.yearly, 1): self = .yearly
            default: self = .custom
            }
        }

        /// 프리셋의 EKRecurrenceRule. `.none`/`.custom`은 nil — custom은 "건드리지 말라"는 신호.
        func rule() -> EKRecurrenceRule? {
            let make = { EKRecurrenceRule(recurrenceWith: $0, interval: $1, end: nil) }
            switch self {
            case .none, .custom: return nil
            case .daily: return make(.daily, 1)
            case .weekly: return make(.weekly, 1)
            case .biweekly: return make(.weekly, 2)
            case .monthly: return make(.monthly, 1)
            case .yearly: return make(.yearly, 1)
            }
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
