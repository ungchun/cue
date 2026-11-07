//
//  EventEditDraft+Alarm.swift
//  cue / Presentation
//

import EventKit
import Foundation

extension EventEditDraft {
    /// 알림 한 칸 — Apple 캘린더 프리셋(상대 오프셋) + 사용자 지정(절대 일시).
    /// 그 밖(프리셋 밖 오프셋·위치 알림 등)은 `.custom`(표시·보존 전용).
    ///
    /// 프리셋은 이벤트 종류마다 다르다 — 시간 지정은 "N분/시간/일 전", 종일은 "N일 전(오전 9시)".
    /// 종일 프리셋은 EventKit에 **자정 기준 상대 오프셋**으로 저장된다
    /// (당일 오전 9시 = +9시간, 1일 전 오전 9시 = -15시간).
    enum Alarm: Hashable {
        case none
        case atTime                     // 이벤트 당시(오프셋 0)
        case minutesBefore(Int)         // 시간 지정 프리셋 분 단위만(presetMinutes)
        case daysBeforeAt9AM(Int)       // 종일 프리셋 — N일 전 오전 9시(0 = 당일, allDayPresetDays)
        case absolute(Date)             // 사용자 지정 — 절대 일시
        case custom

        /// 시간 지정 이벤트 분 프리셋 — Apple 캘린더와 동일 구성.
        static let presetMinutes = [5, 10, 15, 30, 60, 120, 1_440, 2_880, 10_080]
        /// 종일 이벤트 일 프리셋 — 당일·1일·2일·1주 전, 모두 오전 9시.
        static let allDayPresetDays = [0, 1, 2, 7]
        private static let nineAM: TimeInterval = 9 * 3_600
        private static let day: TimeInterval = 86_400

        /// 선택 메뉴에 노출하는 프리셋(사용자 지정·custom 제외).
        static func presets(isAllDay: Bool) -> [Alarm] {
            isAllDay
                ? [.none] + allDayPresetDays.map(Alarm.daysBeforeAt9AM)
                : [.none, .atTime] + presetMinutes.map(Alarm.minutesBefore)
        }

        /// 이벤트 알림 목록 → 두 칸. 3개 이상이면 두 칸 모두 `.custom`(apply가 통째로 보존).
        static func slots(from alarms: [EKAlarm]?, isAllDay: Bool, eventStart: Date) -> (first: Alarm, second: Alarm) {
            guard let alarms, !alarms.isEmpty else { return (.none, .none) }
            guard alarms.count <= 2 else { return (.custom, .custom) }
            let ordered = ordered(alarms, eventStart: eventStart)
            let first = Alarm(alarm: ordered[0], isAllDay: isAllDay)
            let second = ordered.count == 2 ? Alarm(alarm: ordered[1], isAllDay: isAllDay) : .none
            return (first, second)
        }

        /// 칸 순서 — 이벤트에 가까이 울리는 알림이 첫 칸. EventKit은 추가한 순서를 보존하지 않고
        /// 이른 알림부터 돌려주므로(시뮬 실측), 읽기(slots)와 쓰기(.custom 원본 복사)가 같은 기준을 써야
        /// 칸과 원본이 어긋나지 않는다.
        static func ordered(_ alarms: [EKAlarm], eventStart: Date) -> [EKAlarm] {
            func trigger(_ alarm: EKAlarm) -> TimeInterval {
                alarm.absoluteDate.map { $0.timeIntervalSince(eventStart) } ?? alarm.relativeOffset
            }
            return alarms.sorted { trigger($0) > trigger($1) }
        }

        init(alarm: EKAlarm, isAllDay: Bool) {
            // 위치(도착·출발) 알림은 우리 폼이 못 그린다 — 보존.
            guard alarm.structuredLocation == nil, alarm.proximity == .none else {
                self = .custom
                return
            }
            if let date = alarm.absoluteDate {
                self = .absolute(date)
                return
            }
            let offset = alarm.relativeOffset
            if isAllDay {
                let daysBefore = (Self.nineAM - offset) / Self.day
                if daysBefore.rounded() == daysBefore, Self.allDayPresetDays.contains(Int(daysBefore)) {
                    self = .daysBeforeAt9AM(Int(daysBefore))
                } else {
                    self = .custom
                }
            } else if offset == 0 {
                self = .atTime
            } else if offset < 0, offset.truncatingRemainder(dividingBy: 60) == 0,
                      Self.presetMinutes.contains(Int(-offset) / 60) {
                self = .minutesBefore(Int(-offset) / 60)
            } else {
                self = .custom
            }
        }

        /// 이벤트 시작(종일은 그날 자정) 기준 상대 오프셋(초). 상대 알림이 아니면 nil.
        var relativeOffset: TimeInterval? {
            switch self {
            case .none, .custom, .absolute: return nil
            case .atTime: return 0
            case .minutesBefore(let minutes): return TimeInterval(-minutes * 60)
            case .daysBeforeAt9AM(let days): return Self.nineAM - TimeInterval(days) * Self.day
            }
        }

        /// 저장할 새 EKAlarm. `.none`/`.custom`은 nil(custom은 apply가 원본을 남긴다).
        func makeEKAlarm() -> EKAlarm? {
            if case .absolute(let date) = self { return EKAlarm(absoluteDate: date) }
            return relativeOffset.map { EKAlarm(relativeOffset: $0) }
        }

        /// 종일 여부가 바뀐 뒤에도 유효한 값인지 — 상대 프리셋은 자기 체계에서만 유효.
        func fits(isAllDay: Bool) -> Bool {
            switch self {
            case .none, .absolute, .custom: true
            case .atTime, .minutesBefore: !isAllDay
            case .daysBeforeAt9AM: isAllDay
            }
        }

        var isAbsolute: Bool {
            if case .absolute = self { return true }
            return false
        }
    }
}
