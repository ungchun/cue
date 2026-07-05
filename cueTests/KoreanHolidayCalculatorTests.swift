//
//  KoreanHolidayCalculatorTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct KoreanHolidayCalculatorTests {

    /// 기기 시간대와 무관하게 결정적으로 돌도록 한국 시간대로 고정한 그레고리력.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func days(_ year: Int, _ month: Int) -> Set<Int> {
        KoreanHolidayCalculator.holidayDays(year: year, month: month, calendar: calendar)
    }

    // MARK: - 양력 고정 공휴일

    @Test func fixedSolarHolidaysAppear() {
        #expect(days(2025, 3).contains(1))   // 삼일절
        #expect(days(2025, 6) == [6])        // 현충일(금요일, 대체 없음)
        #expect(days(2025, 8).contains(15))  // 광복절
        #expect(days(2025, 12) == [25])      // 성탄절(목요일)
    }

    @Test func newYearAndMemorialDayGetNoSubstitute() {
        // 현충일 2026-06-06은 토요일이지만 대체 대상이 아니다 → 6일 하나뿐.
        #expect(days(2026, 6) == [6])
        // 신정도 대체 없음 — 2026-01-01은 목요일이라 어차피 평일.
        #expect(days(2026, 1) == [1])
    }

    // MARK: - 음력 공휴일 + 연휴

    @Test func chuseok2025WithSundaySubstitute() {
        // 추석 2025-10-06(월), 연휴 5·6·7. 개천절 3, 한글날 9.
        // 연휴에 일요일(10/5)이 끼어 대체공휴일 8이 추가된다.
        #expect(days(2025, 10) == [3, 5, 6, 7, 8, 9])
    }

    @Test func seollal2026ThreeDayBlock() {
        // 설날 2026-02-17, 연휴 16·17·18. 평일뿐이라 대체 없음.
        #expect(days(2026, 2) == [16, 17, 18])
    }

    // MARK: - 대체공휴일

    @Test func independenceDaySundaySubstitute() {
        // 삼일절 2026-03-01은 일요일 → 대체공휴일 3/2(월).
        #expect(days(2026, 3) == [1, 2])
    }

    @Test func foundationDaySaturdaySubstitute() {
        // 개천절 2026-10-03은 토요일 → 다음 평일 10/5로 대체. 한글날 9는 금요일(대체 없음).
        #expect(days(2026, 10) == [3, 5, 9])
    }

    @Test func overlappingHolidaysGetSingleSubstitute() {
        // 어린이날과 부처님오신날이 둘 다 2025-05-05 → 겹침으로 대체공휴일 5/6 하루.
        #expect(days(2025, 5) == [5, 6])
    }

    // MARK: - 공휴일 없는 달

    @Test func monthsWithoutHolidaysAreEmpty() {
        #expect(days(2025, 4).isEmpty)
        #expect(days(2025, 11).isEmpty)
    }
}
