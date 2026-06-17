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
}
