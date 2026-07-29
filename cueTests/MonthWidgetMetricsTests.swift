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

    private func chipHeight(rowHeight: CGFloat, slots: Int) -> CGFloat {
        MonthWidgetMetrics.chipHeight(
            rowHeight: rowHeight, slots: slots,
            headerHeight: header, spacing: spacing, minimum: minimum
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

    @Test func chipHeightGrowsToFillATallRow() {
        // 행이 넉넉하면 칩이 그만큼 두꺼워진다 — 상한을 두면 남는 높이를 아무도 쓰지 않아
        // 마지막 주 아래가 빈 공간으로 남는다.
        let chip = chipHeight(rowHeight: 200, slots: 3)

        #expect(totalHeight(chip: chip, slots: 3) == 200)
    }

    @Test func chipHeightShrinksSoTheRequiredCountAlwaysFits() {
        // 5주 달 기준 행 높이(약 55pt)에서 3개가 반드시 들어가야 한다.
        let chip = chipHeight(rowHeight: 55, slots: 3)

        #expect(totalHeight(chip: chip, slots: 3) <= 55.0001)
    }

    @Test func chipHeightFillsTheRowExactly() {
        // 하한에 걸리지 않는 구간에서는 남는 높이를 **남김없이** 나눠 가진다.
        for rowHeight in stride(from: 45.0, through: 55.0, by: 1.0) {
            let chip = chipHeight(rowHeight: CGFloat(rowHeight), slots: 3)
            #expect(abs(totalHeight(chip: chip, slots: 3) - CGFloat(rowHeight)) < 0.0001)
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
            headerHeight: header, spacing: spacing, minimum: minimum
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
        // 상한은 없다 — 행이 넉넉하면 칩이 그만큼 두꺼워져 행을 채운다.
        for rowHeight in stride(from: 0.0, through: 200.0, by: 7.0) {
            for slots in 1...MonthWidgetMetrics.maximumSlots {
                let chip = MonthWidgetMetrics.chipHeight(rowHeight: CGFloat(rowHeight), slots: slots)
                #expect(chip >= MonthWidgetMetrics.minimumChipHeight)
            }
        }
    }

    /// 격자는 카드 바닥에 여백을 남기고, **남은 높이를 주 행이 남김없이 나눈다.**
    ///
    /// 뷰가 `usableHeight = 전체 - bottomInset`으로 예산을 잡고 행마다 구분선을 하나씩
    /// 그리므로, 그 합이 다시 `usableHeight`가 되어야 마지막 주가 잘리지도 뜨지도 않는다.
    /// 이 관계가 깨지면 마지막 주가 위젯 밖으로 밀려나 "닫히지 않는 하단 여백"이 된다.
    @Test func gridBudgetLeavesTheBottomInsetAndFillsTheRest() {
        // 뷰(`MonthWidgetView.bottomInset`)·테마(`WidgetCalendarTheme.hairline`)는 위젯
        // 익스텐션 타깃이라 여기서 import할 수 없다 — 같은 값을 상수로 두고 관계식만 검증한다.
        let total: CGFloat = 313
        let inset: CGFloat = Spacing.xs
        let hairline: CGFloat = 0.5

        for weekCount in 4...6 {
            let usable = total - inset
            let rowHeight = (usable - hairline * CGFloat(weekCount)) / CGFloat(weekCount)
            let consumed = (rowHeight + hairline) * CGFloat(weekCount)

            #expect(abs(consumed - usable) < 0.0001)
            #expect(abs((total - consumed) - inset) < 0.0001)
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
