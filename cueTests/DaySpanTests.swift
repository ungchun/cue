//
//  DaySpanTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct DaySpanTests {

    /// 기기 시간대와 무관하게 결정적으로 돌도록 고정한 그레고리력.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func days(_ start: Date, _ end: Date) -> [Int] {
        DaySpan.days(from: start, to: end, calendar: calendar)
            .map { calendar.component(.day, from: $0) }
    }

    // MARK: - 종일 일정의 끝 날짜 해석

    @Test func inclusiveAllDayEndStaysOnOneDay() {
        // EventKit이 종일 일정을 마지막 날 23:59:59로 주는 형태.
        #expect(days(date(2026, 8, 15), date(2026, 8, 15, 23, 59, 59)) == [15])
    }

    @Test func exclusiveAllDayEndStaysOnOneDay() {
        // ⚠️ 핵심 — iCalendar(ICS) 표준은 DTEND를 **배타적**으로 쓴다. 공휴일 캘린더는
        // 구독(ICS) 기반이라 하루짜리 공휴일이 "8/15 00:00 ~ 8/16 00:00"으로 올 수 있다.
        // 그대로 훑으면 8/16까지 빨갛게 칠해진다.
        #expect(days(date(2026, 8, 15), date(2026, 8, 16)) == [15])
    }

    @Test func midnightEndingTimedEventStaysOnItsOwnDay() {
        // 23시~자정 일정이 다음 날로 번지면 안 된다(위젯 격자에서 이미 지키던 규칙).
        #expect(days(date(2026, 8, 15, 23, 0), date(2026, 8, 16)) == [15])
    }

    // MARK: - 여러 날 연휴

    @Test func multiDayHolidayCoversEveryDay() {
        // 대만·중국 춘절, 한국 설날처럼 연휴가 이벤트 **하나**로 오는 경우.
        // ICS 배타적 끝(2/20 00:00)이라 실제 연휴는 2/17~2/19다.
        #expect(days(date(2026, 2, 17), date(2026, 2, 20)) == [17, 18, 19])
    }

    @Test func multiDayHolidayCrossingMonthBoundary() {
        // 1/31 ~ 2/2 연휴 — 달을 넘어간다. 호출부가 표시 월로 거르므로 여기서는 전부 돌려준다.
        #expect(days(date(2026, 1, 31), date(2026, 2, 3)) == [31, 1, 2])
    }

    // MARK: - 경계

    @Test func zeroLengthItemCoversItsDay() {
        // 미리알림은 길이가 없다(start == end) — 1초 당기는 보정이 걸리면 안 된다.
        let due = date(2026, 8, 15, 9, 0)
        #expect(days(due, due) == [15])
    }

    @Test func endBeforeStartFallsBackToStartDay() {
        // 깨진 데이터 방어 — 끝이 시작보다 앞서도 시작일 하루는 돌려준다(빈 배열 금지).
        #expect(days(date(2026, 8, 15), date(2026, 8, 10)) == [15])
    }
}
