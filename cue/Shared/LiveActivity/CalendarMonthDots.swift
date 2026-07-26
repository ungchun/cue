//
//  CalendarMonthDots.swift
//  cue / Shared
//
//  LA 잠금화면 월간 캘린더(MonthCalendarView)의 날짜별 일정 점 계산.
//  앱·익스텐션 양쪽에 컴파일되지만(공유 인텐트가 참조) EKEventStore 조회는 **앱 프로세스에서만**
//  실행된다 — 발행(ActivityKitLiveActivityService)과 월 이동 인텐트(ShiftCalendarMonthIntent)가
//  이 provider를 호출한다. EventKit 경계 글루라 RED 면제.
//

import EventKit
import Foundation
import os

enum CalendarMonthDots {
    /// [진단용 임시] 점이 비는 원인 격리 로그 — 원인 확정 후 제거한다.
    /// 듀얼 타깃 파일이라 앱 전용 AppLogger 대신 로컬 Logger를 쓴다.
    private static let log = Logger(subsystem: "azhy.cue", category: "monthDots")
    /// 하루 최대 3점 — 초과분은 안 그린다. 점이 늘어 ContentState가 커지면 리스트 아이템 수를
    /// 적응형 fitter가 알아서 줄여 4KB 한도를 지킨다.
    static let maxDotsPerDay = 3

    /// 표시 월(`now + monthOffset`)의 날짜별 일정 점(일 정수 기준). 캘린더 권한이 없으면 빈 배열.
    /// 숨긴 캘린더는 App Group의 `hiddenCalendarIDs`로 거른다. 오늘은 제외(밑줄로 표시).
    static func dots(monthOffset: Int, now: Date = Date(), calendar: Calendar = .current) -> [LiveMonthDot] {
        let status = EKEventStore.authorizationStatus(for: .event)
        let processName = ProcessInfo.processInfo.processName
        guard status == .fullAccess || status == .writeOnly else {
            log.error("[진단] 권한 미달로 점 없음 — status=\(status.rawValue) process=\(processName)")
            return []
        }

        let base = calendar.startOfDay(for: now)
        guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: base),
              let month = calendar.dateInterval(of: .month, for: monthDate) else { return [] }

        let store = EKEventStore()
        let predicate = store.predicateForEvents(withStart: month.start, end: month.end, calendars: nil)
        let hidden = hiddenCalendarIDs()
        let todayStart = calendar.startOfDay(for: now)

        // 시작 시간순으로 정렬해 하루 안 점 순서를 앱 목록과 맞춘다.
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        var order: [Int] = []
        var byDay: [Int: [String]] = [:]
        for event in events {
            guard !hidden.contains(event.calendar.calendarIdentifier) else { continue }
            let dayStart = calendar.startOfDay(for: event.startDate)
            guard dayStart >= month.start, dayStart < month.end, dayStart != todayStart else { continue }
            let day = calendar.component(.day, from: dayStart)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(hex(from: event.calendar.cgColor) ?? "")
        }
        log.info("""
        [진단] offset=\(monthOffset) process=\(processName) status=\(status.rawValue) \
        조회이벤트=\(events.count) 숨김캘린더=\(hidden.count) 점날짜=\(order.count)
        """)
        return order.sorted().map {
            LiveMonthDot(day: $0, colorHexes: Array(byDay[$0, default: []].prefix(maxDotsPerDay)))
        }
    }

    private static func hiddenCalendarIDs() -> Set<String> {
        Set(SharedAppGroup.defaults.stringArray(forKey: SharedAppGroup.Keys.hiddenCalendarIDs) ?? [])
    }

    /// `CGColor` → "#RRGGBB". `EventMapper.hex`와 동일 규칙(위젯 타깃엔 EventMapper가 없어 복제).
    private static func hex(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(round(max(0, min(1, components[0])) * 255))
        let g = Int(round(max(0, min(1, components[1])) * 255))
        let b = Int(round(max(0, min(1, components[2])) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
