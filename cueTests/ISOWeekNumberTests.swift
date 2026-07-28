//
//  ISOWeekNumberTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 타임라인 위젯(1일·3일) 좌상단 주차 배지의 계산 검증.
///
/// ISO 8601 주차는 "목요일이 속한 해"가 그 주의 해다 — 연말연시에 전년/차년으로 넘어가는
/// 경계가 유일한 함정이라 그 경계를 집중적으로 검증한다.
struct ISOWeekNumberTests {

    /// UTC 고정 그레고리력 — 기기 타임존과 무관하게 결정론적으로 만든다.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func referenceDayIsWeek31() {
        // 2026-07-27(월). 2026-01-01이 목요일이라 그 주가 1주차 → 7/27은 31주차.
        #expect(ISOWeekNumber.number(for: date(2026, 7, 27), calendar: calendar) == 31)
    }

    @Test func januaryFirstBelongsToWeekOneWhenItIsThursday() {
        // 2026-01-01은 목요일 → ISO 규칙상 그 주가 그해 1주차.
        #expect(ISOWeekNumber.number(for: date(2026, 1, 1), calendar: calendar) == 1)
    }

    @Test func newYearsDayCanBelongToPreviousYearsLastWeek() {
        // 2027-01-01은 금요일 → 그 주의 목요일(2026-12-31)이 2026년 → 2026년 53주차.
        #expect(ISOWeekNumber.number(for: date(2027, 1, 1), calendar: calendar) == 53)
    }

    @Test func lastDaysOfYearCanBelongToNextYearsFirstWeek() {
        // 2025-12-29(월)이 속한 주의 목요일은 2026-01-01 → 2026년 1주차.
        #expect(ISOWeekNumber.number(for: date(2025, 12, 29), calendar: calendar) == 1)
    }

    @Test func weekNumberIsStableAcrossTheWholeWeek() {
        // 같은 ISO 주(월~일)의 모든 날은 같은 주차여야 한다 — 3일 위젯이 열마다
        // 주차를 다시 계산하지 않고 첫 열 기준 하나만 그리는 근거.
        let week = (27...31).map { date(2026, 7, $0) } + [date(2026, 8, 1), date(2026, 8, 2)]
        let numbers = Set(week.map { ISOWeekNumber.number(for: $0, calendar: calendar) })
        #expect(numbers == [31])
    }
}
