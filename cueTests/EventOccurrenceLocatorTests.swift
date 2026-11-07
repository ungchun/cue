//
//  EventOccurrenceLocatorTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 반복 이벤트 회차 선택 규칙 — 같은 ID의 여러 회차 중 탭한 회차를 골라야 한다
/// (ID만으로 조회하면 EventKit이 첫 회차를 줘서 엉뚱한 회차를 수정·삭제하던 버그).
struct EventOccurrenceLocatorTests {

    private struct Candidate: Equatable {
        let id: String?
        let start: Date?
    }

    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private let week: TimeInterval = 7 * 86_400

    private func select(_ candidates: [Candidate], id: String = "series", start: Date) -> Candidate? {
        EventOccurrenceLocator.select(
            from: candidates, eventID: id, occurrenceStart: start,
            id: \.id, start: \.start
        )
    }

    @Test func picksExactMatch() {
        let target = Candidate(id: "series", start: base)

        #expect(select([target], start: base) == target)
    }

    /// 같은 ID의 회차가 여럿이면 시작 시각이 같은 회차 — 첫 회차가 아니라.
    @Test func picksTappedOccurrenceAmongSeries() {
        let first = Candidate(id: "series", start: base)
        let second = Candidate(id: "series", start: base + week)
        let other = Candidate(id: "other", start: base + week)

        #expect(select([first, other, second], start: base + week) == second)
    }

    /// 정확히 맞는 회차가 없으면(시간대 차이·회차 이동) 같은 ID 중 가장 가까운 회차.
    @Test func fallsBackToNearestSameID() {
        let early = Candidate(id: "series", start: base - 3_600)
        let near = Candidate(id: "series", start: base + 600)
        let otherCloser = Candidate(id: "other", start: base)

        #expect(select([early, otherCloser, near], start: base) == near)
    }

    @Test func returnsNilWhenNoSameID() {
        let other = Candidate(id: "other", start: base)

        #expect(select([other], start: base) == nil)
        #expect(select([], start: base) == nil)
    }
}
