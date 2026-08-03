//
//  MemoTextMetricsTests.swift
//  cueTests
//
//  메모 글자 크기 — 메모 탭 · LA · 미리보기가 공유하는 하나의 표.
//

import Foundation
import Testing
@testable import cue

/// 설정의 "작게/보통/크게"가 **어느 화면에서나 같은 크기**를 뜻하게 만드는 규칙.
///
/// 증상(2026-08-03 보고): 메모 탭 글자와 잠금화면 LA·설정 미리보기 글자 크기가 눈에 띄게 다르다.
///
/// 원인 — 두 축이 따로 만들어졌다. 메모 탭은 텍스트 스타일(22/28/34pt), LA는 고정 pt(`44 × 배율`).
/// 캘린더 OFF일 때 LA가 입력보다 1.3배 컸다. 게다가 배율 표가 위젯과 미리보기에 각각 복사돼 있어
/// 한쪽만 고치면 미리보기가 실제 잠금화면과 어긋난다.
///
/// 규칙 — 기준 크기와 배율을 여기 한 곳에 두고, 텍스트 단독 기준을 메모 탭 `.largeTitle`(34pt)에
/// 맞춘다. 설정에서 고른 크기가 입력칸에서 본 크기 그대로 잠금화면에 나오게 하기 위함이다.
struct MemoTextMetricsTests {

    // MARK: - 배율 — 세 화면이 같은 표를 쓴다

    @Test func mapsEachTextSizeToItsScale() {
        #expect(MemoTextMetrics.scale("small") == 0.7)
        #expect(MemoTextMetrics.scale("medium") == 0.85)
        #expect(MemoTextMetrics.scale("large") == 1.0)
    }

    /// 첫 실행(키 미저장)·알 수 없는 값은 보통으로 — 위젯이 App Group에서 읽는 값이라
    /// 없을 수 있다. 크래시나 0배율 대신 기본 크기로 그린다.
    @Test func fallsBackToMediumForMissingOrUnknownValue() {
        #expect(MemoTextMetrics.scale(nil) == 0.85)
        #expect(MemoTextMetrics.scale("huge") == 0.85)
    }

    // MARK: - 기준 크기 — 메모 탭과 일치

    /// 텍스트 단독(캘린더 OFF) 기준은 메모 탭 "크게"(`.largeTitle` 34pt)와 같은 값이다.
    /// 이 값이 44로 돌아가면 잠금화면만 1.3배 커지는 그 버그가 되살아난다.
    @Test func textOnlyBaseMatchesMemoTabLargeTitle() {
        #expect(MemoTextMetrics.textOnlyBase == 34)
    }

    /// 세 단계가 메모 탭 텍스트 스타일(title2 22 / title1 28 / largeTitle 34)과 일치한다.
    /// 소수점 오차는 허용 — 배율 곱셈 결과라 정확히 22.0이 아닐 수 있다.
    @Test func textOnlySizesMatchMemoTabTextStyles() {
        let expected: [(String, CGFloat)] = [("small", 22), ("medium", 28), ("large", 34)]
        for (raw, points) in expected {
            let size = MemoTextMetrics.size(base: MemoTextMetrics.textOnlyBase, textSize: raw)
            #expect(abs(size - points) < 2, "\(raw): \(size) vs \(points)")
        }
    }

    /// 캘린더 ON은 폭이 절반이라 기준이 더 작다 — 단독보다 커지면 안 된다.
    @Test func calendarBaseIsNotLargerThanTextOnly() {
        #expect(MemoTextMetrics.withCalendarBase <= MemoTextMetrics.textOnlyBase)
    }
}
