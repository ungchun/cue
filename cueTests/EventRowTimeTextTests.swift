//
//  EventRowTimeTextTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 일정 행의 시간 문구(`EventRow.timeText`) 분기 — 종일 / 하루짜리 / 여러 날 걸친
/// 일정의 시작·진행중·종료 표시를 섹션 날짜 기준으로 검증한다.
@MainActor
struct EventRowTimeTextTests {
    private let cal = Calendar.current

    private func event(start: Date, end: Date, isAllDay: Bool = false) -> CalendarEvent {
        CalendarEvent(
            id: "e", title: "이벤트",
            startDate: start, endDate: end,
            isAllDay: isAllDay, calendarColorHex: nil, isReadOnly: false
        )
    }

    @Test func allDayShowsHaruJongil() {
        let day = cal.startOfDay(for: Date())
        let e = event(start: day, end: day.addingTimeInterval(86_400), isAllDay: true)

        #expect(EventRow.timeText(for: e, in: day) == "하루 종일")
    }

    @Test func singleDayTimedShowsStartEndRange() {
        // 하루짜리 시간 일정은 "오전 9:00 - 오전 10:00" 형식.
        let day = cal.startOfDay(for: Date())
        let e = event(start: day.addingTimeInterval(9 * 3600), end: day.addingTimeInterval(10 * 3600))

        let text = EventRow.timeText(for: e, in: day)

        #expect(text.contains(" - "))
        #expect(!text.contains("→"))
    }

    // 16일 06:00 ~ 20일 08:00 같은 여러 날 걸친 시간 일정.

    @Test func multiDayStartDaySectionShowsStartTimeWithTrailingArrow() {
        // 시작일(16일) 섹션 → "오전 6:00 →"
        let day16 = cal.startOfDay(for: Date())
        let day20 = cal.date(byAdding: .day, value: 4, to: day16)!
        let e = event(start: day16.addingTimeInterval(6 * 3600), end: day20.addingTimeInterval(8 * 3600))

        let text = EventRow.timeText(for: e, in: day16)

        #expect(text.hasSuffix("→"))
        #expect(!text.hasPrefix("→"))
    }

    @Test func multiDayMiddleDaySectionShowsOngoing() {
        // 사이 날(18일) 섹션 → "진행 중"
        let day16 = cal.startOfDay(for: Date())
        let day18 = cal.date(byAdding: .day, value: 2, to: day16)!
        let day20 = cal.date(byAdding: .day, value: 4, to: day16)!
        let e = event(start: day16.addingTimeInterval(6 * 3600), end: day20.addingTimeInterval(8 * 3600))

        #expect(EventRow.timeText(for: e, in: day18) == "진행 중")
    }

    @Test func multiDayEndDaySectionShowsLeadingArrowWithEndTime() {
        // 종료일(20일) 섹션 → "→ 오전 8:00"
        let day16 = cal.startOfDay(for: Date())
        let day20 = cal.date(byAdding: .day, value: 4, to: day16)!
        let e = event(start: day16.addingTimeInterval(6 * 3600), end: day20.addingTimeInterval(8 * 3600))

        let text = EventRow.timeText(for: e, in: day20)

        #expect(text.hasPrefix("→"))
        #expect(!text.hasSuffix("→"))
    }
}
