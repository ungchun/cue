//
//  LunarDayLabelerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 기대값은 `Calendar(identifier: .dangi)`로 미리 확인한 한국 음력이다(설날·추석·윤달 경계 포함).
struct LunarDayLabelerTests {

    private let labeler = LunarDayLabeler()

    /// 실행 기기 시간대와 무관하게 — 기본은 한국 시간대 그레고리력.
    private func calendar(timeZone: String = "Asia/Seoul") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - 하루

    @Test func convertsGregorianDayToLunarMonthDotDay() {
        let cal = calendar()
        #expect(labeler.label(for: date(2026, 11, 22, cal), calendar: cal) == "10.14")
        // 설날(음력 1월 1일)·추석(8월 15일).
        #expect(labeler.label(for: date(2025, 1, 29, cal), calendar: cal) == "1.1")
        #expect(labeler.label(for: date(2026, 9, 25, cal), calendar: cal) == "8.15")
    }

    /// 2025년은 윤6월이 있다 — 7/24는 평달 6월 그믐, 7/25부터 윤6월, 8/23에 7월로 넘어간다.
    @Test func leapMonthIsPrefixed() {
        let cal = calendar()
        #expect(labeler.label(for: date(2025, 7, 24, cal), calendar: cal) == "6.30")
        #expect(labeler.label(for: date(2025, 7, 25, cal), calendar: cal) == "윤6.1")
        #expect(labeler.label(for: date(2025, 8, 22, cal), calendar: cal) == "윤6.29")
        #expect(labeler.label(for: date(2025, 8, 23, cal), calendar: cal) == "7.1")
    }

    /// 중국 음력(`.chinese`)과 갈리는 날은 한국 음력을 따른다.
    /// 2017년은 한국이 윤5월, 중국이 윤6월. 2026-11-08은 한국 9.29, 중국 9.30.
    @Test func followsKoreanLunarCalendarNotChinese() {
        let cal = calendar()
        #expect(labeler.label(for: date(2017, 6, 24, cal), calendar: cal) == "윤5.1")
        #expect(labeler.label(for: date(2026, 11, 8, cal), calendar: cal) == "9.29")
    }

    /// 칸의 양력 날과 같은 날을 본다 — 다른 시간대 기기에서 그 지역 자정이 하루 밀려 계산되지 않게.
    @Test func usesTimeZoneOfGivenCalendar() {
        let honolulu = calendar(timeZone: "Pacific/Honolulu")
        #expect(labeler.label(for: date(2026, 11, 22, honolulu), calendar: honolulu) == "10.14")
        let utc = calendar(timeZone: "UTC")
        #expect(labeler.label(for: date(2026, 11, 22, utc), calendar: utc) == "10.14")
    }

    // MARK: - 한 달

    @Test func labelsCoverEveryDayOfMonthKeyedByGregorianDay() {
        let cal = calendar()
        let labels = labeler.labels(monthStart: date(2026, 11, 1, cal), calendar: cal)

        #expect(labels.count == 30)
        #expect(Set(labels.keys) == Set(1...30))
        #expect(labels[8] == "9.29")
        #expect(labels[9] == "10.1")
        #expect(labels[22] == "10.14")
    }

    /// 달 중간에 윤달로 넘어가도 날마다 맞는 달을 붙인다.
    @Test func labelsCrossIntoLeapMonthWithinMonth() {
        let cal = calendar()
        let labels = labeler.labels(monthStart: date(2025, 7, 1, cal), calendar: cal)

        #expect(labels.count == 31)
        #expect(labels[24] == "6.30")
        #expect(labels[25] == "윤6.1")
        #expect(labels[31] == "윤6.7")
    }
}
