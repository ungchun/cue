//
//  AllDayStripLimitsTests.swift
//  cueTests
//

import CoreGraphics
import Testing
@testable import cue

/// 종일 줄에서 제목을 몇 개까지 붙일지 — 열 폭에서 역산하는 규칙.
///
/// 이 값이 실제 폭과 어긋나면 좁은 칸에 제목을 우겨넣어 두 글자만 남거나, 반대로 자리가
/// 남는데도 막대로 접힌다. 화면 없이 검증할 수 있게 순수 계산으로 떼어 두었다.
struct AllDayStripLimitsTests {

    /// 3일 위젯 — 열이 좁아 두 개가 한계다.
    @Test func threeDayColumnFitsTwoTitles() {
        // 위젯 338pt에서 인셋(16)·거터(22)를 뺀 뒤 3등분 = 100pt.
        #expect(AllDayStripLimits.titledCount(columnWidth: 100) == 2)
    }

    /// 1일 위젯 — 열이 넓지만 상한에서 멈춘다.
    ///
    /// 계산상 300pt면 일곱 개까지 들어가지만, 그러면 종일 줄이 화면을 지배해
    /// 정작 아래 시간표가 눈에 안 들어온다.
    @Test func oneDayColumnStopsAtTheCap() {
        #expect(AllDayStripLimits.titledCount(columnWidth: 300) == 3)
    }

    /// 아무리 좁아도 **최소 하나**는 제목으로 그린다.
    ///
    /// 0을 돌려주면 종일 일정이 전부 막대로만 남아 그날 무슨 일이 있는지 알 수 없다.
    /// 한 개라도 제목이 있으면 나머지는 "그 외 몇 개"로 읽힌다.
    @Test func neverFallsBelowOneTitle() {
        #expect(AllDayStripLimits.titledCount(columnWidth: 10) == 1)
        #expect(AllDayStripLimits.titledCount(columnWidth: 0) == 1)
    }

    /// 폭이 넓어질수록 개수가 줄지는 않는다 — 단조 증가.
    @Test func countNeverShrinksAsTheColumnGrows() {
        var previous = 0
        for width in stride(from: CGFloat(20), through: 400, by: 10) {
            let count = AllDayStripLimits.titledCount(columnWidth: width)
            #expect(count >= previous)
            previous = count
        }
    }

    /// 막대는 개수를 막는다 — 고정 폭이라 무한정 늘면 제목 칩을 밀어낸다.
    @Test func barsAreCappedSoTheyCannotCrowdOutTitles() {
        let barsWidth = AllDayStripLimits.barWidth * CGFloat(AllDayStripLimits.barLimit)
        // 가장 좁은 열(3일 위젯 100pt)에서도 막대가 절반을 넘지 않아야
        // 제목 칩 두 개가 설 자리가 남는다.
        #expect(barsWidth < 100 / 2)
    }
}
