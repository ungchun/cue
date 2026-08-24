//
//  MonthDotColorsTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 월 격자 한 칸의 점 색 — 위젯과 LA가 같은 달을 같은 모양으로 그리게 하는 규칙.
///
/// 한 건당 점 하나이고, 무엇을 세는지(일정+할일)와 상한(3개)이 두 화면에서 같다.
struct MonthDotColorsTests {

    private func item(
        _ colorHex: String?,
        kind: WidgetCalendarItem.Kind = .timedEvent
    ) -> WidgetCalendarItem {
        let date = Date(timeIntervalSince1970: 1_784_000_000)
        return WidgetCalendarItem(
            id: UUID().uuidString, title: "제목", start: date, end: date,
            kind: kind, colorHex: colorHex, isHighPriority: false
        )
    }

    @Test func keepsOrderOfItems() {
        #expect(MonthDotColors.colors(for: [item("#FF0000"), item("#00FF00")])
                == ["#FF0000", "#00FF00"])
    }

    @Test func sameColorItemsStayAsSeparateDots() {
        // 점 사이가 벌어져 있어 개수가 그대로 읽힌다 — 색으로 묶으면 "몇 건"을 잃는다.
        #expect(MonthDotColors.colors(for: [item("#FF0000"), item("#FF0000")])
                == ["#FF0000", "#FF0000"])
    }

    @Test func remindersCountAsDotsToo() {
        // 할일도 점으로 찍는다 — 일정만 세면 할일뿐인 날이 빈 날로 보인다.
        #expect(MonthDotColors.colors(for: [item("#0000FF", kind: .reminder)]) == ["#0000FF"])
    }

    @Test func eventsAndRemindersShareTheSameCount() {
        #expect(MonthDotColors.colors(for: [item("#FF0000"), item("#0000FF", kind: .reminder)])
                == ["#FF0000", "#0000FF"])
    }

    @Test func stopsAtLimit() {
        // 넷부터는 가장 좁은 셀(20pt 남짓)에서 점끼리 붙는다.
        let colors = MonthDotColors.colors(
            for: [item("#111111"), item("#222222"), item("#333333"), item("#444444")]
        )
        #expect(colors.count == MonthDotColors.maximum)
        #expect(colors == ["#111111", "#222222", "#333333"])
    }

    @Test func colorlessItemStillCountsAsADot() {
        // 색이 없어도 한 건이다 — 그리는 쪽이 폴백 색으로 칠한다.
        #expect(MonthDotColors.colors(for: [item(nil), item("#FF0000")]) == [nil, "#FF0000"])
    }

    @Test func emptyDayHasNoDots() {
        #expect(MonthDotColors.colors(for: []).isEmpty)
    }
}
