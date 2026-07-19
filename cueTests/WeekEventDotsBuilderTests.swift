//
//  WeekEventDotsBuilderTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 이번 주 캘린더 이벤트 → 주간 스트립 점 묶음 계산.
struct WeekEventDotsBuilderTests {

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1   // 일요일 시작 — 결정론적 테스트
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 9) -> Date {
        var cal = calendar
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func event(
        _ id: String, day: (Int, Int, Int), hour: Int = 9,
        color: String?, isAllDay: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: id,
            startDate: date(day.0, day.1, day.2, hour),
            endDate: date(day.0, day.1, day.2, hour + 1),
            isAllDay: isAllDay, calendarColorHex: color, isReadOnly: false
        )
    }

    /// 2026-07-19는 일요일 → 그 주는 7/19(일)~7/25(토). now=7/22(수).
    private let now = { () -> Date in
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal.date(from: DateComponents(year: 2026, month: 7, day: 22, hour: 15))!
    }()

    /// 그날 이벤트마다 점 하나, 색은 캘린더 색. 해당 날의 dayStart로 묶인다.
    @Test func groupsEventsByDayWithColors() {
        let events = [
            event("b", day: (2026, 7, 20), hour: 14, color: "#00FF00"),   // 늦은 시간 → 뒤
            event("a", day: (2026, 7, 20), hour: 9, color: "#FF0000"),    // 이른 시간 → 앞
            event("c", day: (2026, 7, 23), color: "#0000FF"),
        ]
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)

        let mon = dots.first { calendar.isDate($0.dayStart, inSameDayAs: date(2026, 7, 20)) }
        #expect(mon?.colorHexes == ["#FF0000", "#00FF00"])   // 시작 시간순(앱 목록과 동일)
        let thu = dots.first { calendar.isDate($0.dayStart, inSameDayAs: date(2026, 7, 23)) }
        #expect(thu?.colorHexes == ["#0000FF"])
    }

    /// 오늘(7/22)은 밑줄로 표시하므로 점에서 제외한다.
    @Test func excludesToday() {
        let events = [event("today", day: (2026, 7, 22), color: "#FF0000")]
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)
        #expect(dots.allSatisfy { !calendar.isDate($0.dayStart, inSameDayAs: now) })
    }

    /// 이번 주 밖(지난 주·다음 주) 이벤트는 무시한다.
    @Test func ignoresEventsOutsideThisWeek() {
        let events = [
            event("lastWeek", day: (2026, 7, 18), color: "#FF0000"),   // 토(지난 주)
            event("nextWeek", day: (2026, 7, 26), color: "#00FF00"),   // 일(다음 주)
        ]
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)
        #expect(dots.isEmpty)
    }

    /// 하루 최대 4점 — 초과분은 자른다.
    @Test func capsAtFourDotsPerDay() {
        let events = (0..<6).map { event("e\($0)", day: (2026, 7, 21), hour: 8 + $0, color: "#FF0000") }
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)
        let tue = dots.first { calendar.isDate($0.dayStart, inSameDayAs: date(2026, 7, 21)) }
        #expect(tue?.colorHexes.count == 4)
    }

    /// 색이 없는(nil) 이벤트도 점은 찍되, 위젯 폴백용으로 빈 문자열이 아니라 플레이스홀더를 쓴다.
    @Test func includesEventsWithoutColor() {
        let events = [event("noColor", day: (2026, 7, 20), color: nil)]
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)
        let mon = dots.first { calendar.isDate($0.dayStart, inSameDayAs: date(2026, 7, 20)) }
        #expect(mon?.colorHexes.count == 1)
    }

    /// 이벤트 없는 날은 항목 자체가 없다(빈 배열 엔트리 없음).
    @Test func omitsDaysWithoutEvents() {
        let events = [event("a", day: (2026, 7, 20), color: "#FF0000")]
        let dots = WeekEventDotsBuilder.build(events: events, now: now, calendar: calendar)
        #expect(dots.count == 1)
    }
}
