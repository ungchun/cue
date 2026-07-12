//
//  MonthCalendarGridTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct MonthCalendarGridTests {

    /// 결정적 그리드용 — 명시적 firstWeekday를 가진 그레고리력. 로케일을 ko_KR로 고정해
    /// 월 라벨("10월")·요일 심볼("일"/"토") assert가 실행 기기 언어와 무관하게 결정론적이 되게 한다
    /// (MonthCalendarGrid 포매터는 전달된 calendar.locale을 따른다).
    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - 그리드 모양

    @Test func octoberGridStartsOnThursdayColumn() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthCalendarGrid(now: date(2026, 10, 15, cal), monthOffset: 0, calendar: cal)

        #expect(grid.year == 2026)
        #expect(grid.month == 10)
        // Oct 1 2026 = 목요일 → 일 시작 달력에서 앞 4칸 비고 목·금·토에 1·2·3.
        #expect(grid.weeks.first == [nil, nil, nil, nil, 1, 2, 3])
        #expect(grid.weeks.last == [25, 26, 27, 28, 29, 30, 31])
        #expect(grid.weeks.count == 5)   // 4 + 31 = 35칸 → 정확히 5행
    }

    @Test func augustNeedsSixRows() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthCalendarGrid(now: date(2026, 8, 1, cal), monthOffset: 0, calendar: cal)

        // Aug 1 2026 = 토요일 → 앞 6칸 비고, 31일 → 6칸 + 31 = 37칸 → 6행.
        #expect(grid.weeks.first == [nil, nil, nil, nil, nil, nil, 1])
        #expect(grid.weeks.count == 6)
    }

    @Test func februaryNonLeapNeedsExactlyFourRows() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthCalendarGrid(now: date(2026, 2, 10, cal), monthOffset: 0, calendar: cal)

        // Feb 1 2026 = 일요일(첫 칸) & 28일 → 정확히 4행, 여백 없음.
        #expect(grid.weeks.first == [1, 2, 3, 4, 5, 6, 7])
        #expect(grid.weeks.last == [22, 23, 24, 25, 26, 27, 28])
        #expect(grid.weeks.count == 4)
    }

    @Test func firstWeekdayMondayShiftsLeadingBlanks() {
        let cal = calendar(firstWeekday: 2)
        let grid = MonthCalendarGrid(now: date(2026, 10, 15, cal), monthOffset: 0, calendar: cal)

        // 월 시작 달력 → Oct 1(목) 앞 3칸(월·화·수)만 빔.
        #expect(grid.weeks.first == [nil, nil, nil, 1, 2, 3, 4])
    }

    // MARK: - 요일 헤더 · 요일 인덱스

    @Test func weekdaySymbolsAndIndexFollowSundayStart() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthCalendarGrid(now: date(2026, 10, 15, cal), monthOffset: 0, calendar: cal)

        #expect(grid.weekdaySymbols.first == "일")
        #expect(grid.weekdaySymbols.last == "토")
        #expect(grid.weekdayIndex(column: 0) == 1)   // 일요일
        #expect(grid.weekdayIndex(column: 6) == 7)   // 토요일
    }

    @Test func weekdaySymbolsAndIndexFollowMondayStart() {
        let cal = calendar(firstWeekday: 2)
        let grid = MonthCalendarGrid(now: date(2026, 10, 15, cal), monthOffset: 0, calendar: cal)

        #expect(grid.weekdaySymbols.first == "월")
        #expect(grid.weekdaySymbols.last == "일")
        #expect(grid.weekdayIndex(column: 0) == 2)   // 월요일
        #expect(grid.weekdayIndex(column: 6) == 1)   // 일요일
    }

    // MARK: - monthOffset 산술 · 클램프

    @Test func offsetShiftsAcrossYearBoundary() {
        let cal = calendar(firstWeekday: 1)
        let now = date(2026, 1, 15, cal)

        let previous = MonthCalendarGrid(now: now, monthOffset: -1, calendar: cal)
        #expect(previous.year == 2025)
        #expect(previous.month == 12)

        let ahead = MonthCalendarGrid(now: now, monthOffset: 12, calendar: cal)
        #expect(ahead.year == 2027)
        #expect(ahead.month == 1)
    }

    @Test func offsetIsClampedToTwelveMonths() {
        #expect(MonthCalendarGrid.clampedOffset(13) == 12)
        #expect(MonthCalendarGrid.clampedOffset(-13) == -12)
        #expect(MonthCalendarGrid.clampedOffset(3) == 3)

        let cal = calendar(firstWeekday: 1)
        // now=2026-01, offset -13 → -12로 클램프 → 2025-01.
        let clamped = MonthCalendarGrid(now: date(2026, 1, 15, cal), monthOffset: -13, calendar: cal)
        #expect(clamped.year == 2025)
        #expect(clamped.month == 1)
    }

    // MARK: - isToday

    @Test func isTodayOnlyAtOffsetZeroMatchingDay() {
        let cal = calendar(firstWeekday: 1)
        let now = date(2026, 10, 15, cal)

        let current = MonthCalendarGrid(now: now, monthOffset: 0, calendar: cal)
        #expect(current.isToday(day: 15))
        #expect(!current.isToday(day: 14))

        // 다른 달에는 같은 날이어도 오늘 아님.
        let nextMonth = MonthCalendarGrid(now: now, monthOffset: 1, calendar: cal)
        #expect(!nextMonth.isToday(day: 15))
    }

    // MARK: - 월 라벨

    @Test func monthLabelsWithNeighbors() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthCalendarGrid(now: date(2026, 10, 15, cal), monthOffset: 0, calendar: cal)

        #expect(grid.monthLabel == "10월")
        #expect(grid.previousMonthLabel == "9월")
        #expect(grid.nextMonthLabel == "11월")
    }

    @Test func monthLabelsWrapAtYearBoundary() {
        let cal = calendar(firstWeekday: 1)

        let december = MonthCalendarGrid(now: date(2026, 12, 10, cal), monthOffset: 0, calendar: cal)
        #expect(december.monthLabel == "12월")
        #expect(december.nextMonthLabel == "1월")

        let january = MonthCalendarGrid(now: date(2026, 1, 10, cal), monthOffset: 0, calendar: cal)
        #expect(january.monthLabel == "1월")
        #expect(january.previousMonthLabel == "12월")
    }
}
