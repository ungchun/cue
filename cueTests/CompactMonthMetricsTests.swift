//
//  CompactMonthMetricsTests.swift
//  cueTests
//

import CoreGraphics
import Testing
@testable import cue

/// 좁은 월 격자의 **행 최소 높이** — 6주 달이 좁은 기기에서 잘리지 않게 하는 하한.
///
/// 위젯 높이는 여기서 계산하지 않는다. 예전엔 기기 높이를 상수(141pt)로 박아 행 높이를
/// 못 박았는데, 실제 위젯이 그보다 커서 격자만 쪼그라들었다(실기기 확인). 지금은 행이
/// 주어진 높이를 나눠 갖고, 이 값은 눌릴 수 있는 바닥으로만 쓴다.
struct CompactMonthMetricsTests {

    /// 행 최소 높이는 **글자가 실제로 차지하는 부분 + 점**을 담아야 한다.
    ///
    /// 줄높이 전체가 아니라 디센더를 뺀 값이 기준이다 — 숫자에는 디센더가 없어 그 자리가
    /// 늘 비고, 점이 거기 앉는다(→ `CompactMonthGrid.dayCell`).
    @Test func minimumRowHoldsTheGlyphAndItsDot() {
        let glyph = CompactMonthMetrics.dayNumberLine - CompactMonthMetrics.dayNumberDescender

        #expect(CompactMonthMetrics.minimumRowHeight >= glyph + CompactMonthMetrics.dotSize)
    }

    /// 디센더 몫이 실제로 존재해야 한다 — 0이면 절약이 없어 계산의 전제가 무너진다.
    @Test func theDescenderActuallyLeavesRoom() {
        #expect(CompactMonthMetrics.dayNumberDescender > 0)
        #expect(CompactMonthMetrics.dayNumberDescender < CompactMonthMetrics.dayNumberLine)
    }

    /// 6주 달이 가장 좁은 기기(141pt)에 들어가야 한다.
    ///
    /// 행은 늘어날 수 있지만 **줄어들 수는 없으므로**, 최소 높이 × 6 + 요일 줄이
    /// 그 기기의 격자 몫을 넘으면 어떤 수를 써도 잘린다.
    @Test func sixWeeksFitTheSmallestDevice() {
        let smallestWidget: CGFloat = 141
        // 제목 줄과 여백에 넉넉히 30pt를 떼어 주고도 남아야 한다.
        let gridShare = smallestWidget - 30
        let weekdayHeader = CompactMonthMetrics.dayNumberLine
        let needed = weekdayHeader + CompactMonthMetrics.minimumRowHeight * 6

        #expect(needed <= gridShare)
    }

    /// 6주 달은 날짜 여백을 깎는다 — 행이 얇아진 만큼 글자가 들어갈 자리를 만든다.
    @Test func sixWeekMonthTrimsTheDayNumberPadding() {
        #expect(CompactMonthMetrics.dayNumberPadding(weekCount: 6)
                < CompactMonthMetrics.dayNumberPadding(weekCount: 5))
    }

}

/// 사이드 목록이 **네 줄**을 세운다 — 기기 높이와 무관하게.
///
/// 줄들이 주어진 높이를 나눠 가지므로(→ `WidgetItemListView`) 몇 pt인지 계산할 필요가
/// 없다. 예전엔 높이에서 역산하다 좁은 기기에서 조용히 셋으로 줄었다.
struct UpcomingListMetricsTests {

    /// 개수는 넷으로 고정 — 기기마다 달라지면 같은 위젯이 아니게 된다.
    @Test func alwaysShowsFourRows() {
        #expect(UpcomingListMetrics.rowCount == 4)
    }
}
