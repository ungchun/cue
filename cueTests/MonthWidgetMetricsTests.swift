//
//  MonthWidgetMetricsTests.swift
//  cueTests
//

import CoreGraphics
import Foundation
import Testing
@testable import cue

/// 월 캘린더 위젯 셀의 높이 예산.
///
/// 칸 수는 **주 수가 정하고**(5주 3개·6주 2개), 칩 높이가 그 개수에 맞춰 눌린다.
/// 높이 계산이 후하면 칩이 셀을 넘쳐 그리드가 위젯 밖으로 밀려나므로 경계를 집중 검증한다.
struct MonthWidgetMetricsTests {

    private let header: CGFloat = 16
    private let spacing: CGFloat = 1
    private let minimum: CGFloat = 9
    private let maximum: CGFloat = 14

    private func chipHeight(rowHeight: CGFloat, slots: Int) -> CGFloat {
        MonthWidgetMetrics.chipHeight(
            rowHeight: rowHeight, slots: slots,
            headerHeight: header, spacing: spacing, minimum: minimum, maximum: maximum
        )
    }

    /// 칩 `slots`개 + 간격 + 날짜 줄이 실제로 행 높이 안에 들어가는지.
    private func totalHeight(chip: CGFloat, slots: Int) -> CGFloat {
        header + chip * CGFloat(slots) + spacing * CGFloat(slots - 1)
    }

    // MARK: - 칸 수

    @Test func slotCountFollowsTheNumberOfWeeks() {
        #expect(MonthWidgetMetrics.slotCount(weekCount: 4) == 4)
        #expect(MonthWidgetMetrics.slotCount(weekCount: 5) == 3)
        #expect(MonthWidgetMetrics.slotCount(weekCount: 6) == 2)
    }

    @Test func slotCountClampsUnexpectedWeekCounts() {
        // 그리드는 4~6주만 만들지만, 범위를 벗어난 입력도 유효한 칸 수를 내야 한다.
        #expect(MonthWidgetMetrics.slotCount(weekCount: 1) == MonthWidgetMetrics.maximumSlots)
        #expect(MonthWidgetMetrics.slotCount(weekCount: 9) == 2)
    }

    // MARK: - 칩 높이

    @Test func chipHeightStopsGrowingAtTheTextLineHeight() {
        // 행이 넉넉해도(4주 달) 배경만 두꺼워지면 어색하다 — 글자 줄높이에서 멈춘다.
        #expect(chipHeight(rowHeight: 200, slots: 3) == maximum)
    }

    @Test func chipHeightShrinksSoTheRequiredCountAlwaysFits() {
        // 5주 달 기준 행 높이(약 55pt)에서 3개가 반드시 들어가야 한다.
        let chip = chipHeight(rowHeight: 55, slots: 3)

        #expect(chip < maximum)
        #expect(totalHeight(chip: chip, slots: 3) <= 55.0001)
    }

    @Test func chipHeightFillsTheRowExactly() {
        // 상한·하한에 걸리지 않는 구간에서는 남는 높이를 정확히 나눠 가진다.
        for rowHeight in stride(from: 45.0, through: 55.0, by: 1.0) {
            let chip = chipHeight(rowHeight: CGFloat(rowHeight), slots: 3)
            #expect(totalHeight(chip: chip, slots: 3) <= CGFloat(rowHeight) + 0.0001)
        }
    }

    @Test func chipHeightNeverDropsBelowTheLegibleMinimum() {
        // 행이 아무리 얇아도 글자가 형태를 잃는 높이까지는 내려가지 않는다.
        // 대신 칩이 셀을 넘칠 수 있고, 그건 뷰가 잘라낸다.
        #expect(chipHeight(rowHeight: 20, slots: 3) == minimum)
        #expect(chipHeight(rowHeight: 0, slots: 2) == minimum)
        #expect(chipHeight(rowHeight: -30, slots: 2) == minimum)
    }

    @Test func zeroSlotsDoNotDivideByZero() {
        #expect(MonthWidgetMetrics.chipHeight(
            rowHeight: 100, slots: 0,
            headerHeight: header, spacing: spacing, minimum: minimum, maximum: maximum
        ) == minimum)
    }

    @Test func fewerSlotsGetTallerChips() {
        // 6주 달(2칸)의 칩이 5주 달(3칸)보다 얇아지는 일은 없어야 한다.
        let five = chipHeight(rowHeight: 50, slots: 3)
        let six = chipHeight(rowHeight: 50, slots: 2)

        #expect(six >= five)
    }

    // MARK: - 실제 폰트 메트릭 기반 경로

    @Test func realMetricsStayWithinBounds() {
        // 폰트 메트릭이 기기·OS에 따라 흔들려도 계산은 항상 유효 범위 안에 있어야 한다.
        for rowHeight in stride(from: 0.0, through: 200.0, by: 7.0) {
            for slots in 1...MonthWidgetMetrics.maximumSlots {
                let chip = MonthWidgetMetrics.chipHeight(rowHeight: CGFloat(rowHeight), slots: slots)
                #expect(chip >= MonthWidgetMetrics.minimumChipHeight)
                #expect(chip <= MonthWidgetMetrics.chipLine.rounded(.up))
            }
        }
    }

    @Test func realMetricsFitThreeChipsInAFiveWeekRow() {
        // systemLarge에서 5주 달의 행 높이는 대략 55pt — 여기서 3개가 들어가야 한다.
        let chip = MonthWidgetMetrics.chipHeight(rowHeight: 55, slots: 3)
        let used = MonthWidgetMetrics.dayNumberHeight
            + MonthWidgetMetrics.dayNumberGap
            + chip * 3
            + MonthWidgetMetrics.chipSpacing * 2

        #expect(used <= 55.0001)
    }
}
