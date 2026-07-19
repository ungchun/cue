//
//  WeekEventDotsBuilder.swift
//  cue / Domain
//

import Foundation

/// 이번 주 캘린더 이벤트를 Dynamic Island 주간 스트립의 날짜별 점 묶음으로 변환한다.
///
/// 규칙: 이번 주(로케일 주 시작 요일 기준 7일) 안의 이벤트만, **오늘은 제외**(오늘은 밑줄로
/// 표시), 이벤트당 점 하나(색 중복 허용), 하루 최대 `maxDotsPerDay`개. 이벤트가 없는 날은
/// 항목을 만들지 않는다. 색은 이벤트의 캘린더 색 hex 그대로 — 없으면 `""`(위젯이 시스템색 폴백).
enum WeekEventDotsBuilder {
    static let maxDotsPerDay = 4

    static func build(
        events: [CalendarEvent],
        now: Date,
        calendar: Calendar = .current
    ) -> [LiveDayEventDots] {
        let todayStart = calendar.startOfDay(for: now)
        guard let (weekStart, weekEnd) = weekRange(for: now, calendar: calendar) else { return [] }

        // 앱 내 일정 목록과 동일하게 하루 안에서 시작 시간 오름차순으로 점을 배치한다.
        var order: [Date] = []
        var byDay: [Date: [String]] = [:]
        for event in events.sorted(by: { $0.startDate < $1.startDate }) {
            let day = calendar.startOfDay(for: event.startDate)
            guard day >= weekStart, day < weekEnd else { continue }   // 이번 주만
            guard day != todayStart else { continue }                 // 오늘 제외
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(event.calendarColorHex ?? "")
        }

        return order.sorted().map { day in
            LiveDayEventDots(dayStart: day, colorHexes: Array(byDay[day, default: []].prefix(maxDotsPerDay)))
        }
    }

    /// 이번 주 범위 `[start, end)` — 주 시작일(자정, 사용자 지역의 `firstWeekday` 기준)부터 7일.
    /// 발행 경로(ViewModel)가 이 범위로 캘린더 이벤트를 조회할 때도 재사용한다.
    static func weekRange(for now: Date, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let start = calendar.date(byAdding: .day, value: -offset, to: today),
              let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
        return (start, end)
    }
}
