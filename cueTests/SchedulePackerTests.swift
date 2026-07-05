//
//  SchedulePackerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct SchedulePackerTests {

    private func day(id: String, label: String, count: Int, allDay: Bool = false) -> LiveScheduleDay {
        let events = (0..<count).map { i in
            LiveEventItem(
                id: "\(id)-\(i)",
                title: "이벤트 \(i)",
                startDate: Date(timeIntervalSince1970: Double(i * 3600)),
                endDate: Date(timeIntervalSince1970: Double(i * 3600 + 1800)),
                timeText: "",
                calendarColorHex: nil,
                isAllDay: allDay
            )
        }
        return LiveScheduleDay(id: id, label: label, events: events)
    }

    @Test func emptyDaysProduceEmptyColumns() {
        let (left, right) = SchedulePacker.pack([])
        #expect(left.isEmpty)
        #expect(right.isEmpty)
    }

    @Test func fewEventsAllGoLeftAndRightStaysEmpty() {
        let (left, right) = SchedulePacker.pack([day(id: "d", label: "오늘", count: 1)])

        #expect(right.isEmpty)               // 적으면 오른쪽 안 씀
        #expect(left.count == 1)
        #expect(left.first?.label == "오늘")  // 첫(유일) 청크에 헤더
        #expect(left.first?.events.count == 1)
    }

    @Test func multipleSmallDaysStackInLeft() {
        let (left, right) = SchedulePacker.pack([
            day(id: "a", label: "오늘", count: 1),
            day(id: "b", label: "내일", count: 1),
        ])

        #expect(right.isEmpty)
        #expect(left.map(\.label) == ["오늘", "내일"])
    }

    @Test func overflowingDaySplitsToRightWithoutRepeatingHeader() {
        // 한 날에 많은 이벤트 → 두 열을 다 채우고 넘침.
        let (left, right) = SchedulePacker.pack([day(id: "big", label: "오늘", count: 40)])

        #expect(!left.isEmpty)
        #expect(!right.isEmpty)
        #expect(left.first?.label == "오늘")            // 왼쪽 첫 청크에만 헤더
        #expect(right.allSatisfy { $0.label == nil })   // 오른쪽 연속분은 헤더 생략

        // 이벤트 순서 보존 + 중복 없음 + 원본의 앞부분(prefix).
        let placed = left.flatMap { $0.events.map(\.id) } + right.flatMap { $0.events.map(\.id) }
        #expect(Set(placed).count == placed.count)
        #expect(placed == (0..<40).map { "big-\($0)" }.prefix(placed.count).map { $0 })
    }

    // MARK: - 단일 컬럼 (캘린더 함께 표시 시 오른쪽 반쪽)

    /// 적은 이벤트는 헤더와 함께 그대로 들어간다.
    @Test func singleColumnKeepsFewEventsWithHeader() {
        let chunks = SchedulePacker.packSingleColumn([day(id: "d", label: "오늘", count: 1)])

        #expect(chunks.count == 1)
        #expect(chunks.first?.label == "오늘")
        #expect(chunks.first?.events.count == 1)
    }

    /// 넘치는 이벤트는 한 컬럼 높이(columnMax)에서 잘린다 — 이어 그릴 두 번째 열이 없다.
    @Test func singleColumnTruncatesOverflow() {
        let chunks = SchedulePacker.packSingleColumn([day(id: "big", label: "오늘", count: 40)])

        let placed = chunks.flatMap { $0.events.map(\.id) }
        #expect(placed.count < 40)                     // 다 못 들어간다
        #expect(placed == (0..<placed.count).map { "big-\($0)" })   // 순서 보존 prefix
    }

    /// 단일 컬럼은 2열 패킹의 왼쪽 열과 동일하다 — 같은 채움 규칙을 공유한다.
    @Test func singleColumnMatchesLeftColumnOfTwoColumnPack() {
        let days = [
            day(id: "a", label: "오늘", count: 2),
            day(id: "b", label: "내일", count: 3),
            day(id: "c", label: "모레", count: 3),
        ]

        let single = SchedulePacker.packSingleColumn(days)
        let (left, _) = SchedulePacker.pack(days)

        #expect(single == left)
    }
}
