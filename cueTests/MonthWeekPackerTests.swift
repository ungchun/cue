//
//  MonthWeekPackerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 월 캘린더 위젯의 **주 단위** 칸 배치.
///
/// 핵심은 여러 날에 걸친 일정이 그 주의 모든 날에서 **같은 칸**에 앉는 것이다.
/// 날짜별로 따로 채우면 하나의 일정이 셀마다 다른 줄에 그려져 세 토막으로 보인다.
struct MonthWeekPackerTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }

    private func item(
        _ id: String,
        kind: WidgetCalendarItem.Kind = .timedEvent,
        startDay: Int = 1,
        hour: Int = 9
    ) -> WidgetCalendarItem {
        WidgetCalendarItem(
            id: id, title: id, start: date(startDay, hour: hour), end: date(startDay, hour: hour + 1),
            kind: kind, colorHex: nil, isHighPriority: false
        )
    }

    /// 항목을 지정한 날들에 복제해 넣는다 — 데이터 소스가 걸치는 날마다 넣는 것과 같다.
    private func spread(
        _ item: WidgetCalendarItem,
        over days: [Int],
        into table: inout [Int: [WidgetCalendarItem]]
    ) {
        for day in days { table[day, default: []].append(item) }
    }

    private let week = [1, 2, 3, 4, 5, 6, 7].map { Optional($0) }

    /// 그 날 셀에서 항목이 앉은 칸 번호. 없으면 `nil`.
    private func lane(of id: String, day: Int, in layout: MonthWeekLayout) -> Int? {
        layout.lanes(forDay: day).firstIndex { $0?.id == id }
    }

    // MARK: - 연속 일정

    @Test func aMultiDayEventKeepsTheSameLaneAcrossEveryDay() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("trip", startDay: 3), over: [3, 4, 5], into: &table)
        // 앞선 날에 하루짜리를 섞어 넣어도 연속 일정이 흩어지면 안 된다.
        spread(item("solo3", startDay: 3), over: [3], into: &table)
        spread(item("solo4", startDay: 4), over: [4], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)
        let lanes = [3, 4, 5].map { lane(of: "trip", day: $0, in: layout) }

        #expect(lanes.allSatisfy { $0 != nil })
        #expect(Set(lanes.compactMap { $0 }).count == 1)
    }

    @Test func longerEventsTakeTheTopLanes() {
        // 하루짜리부터 채우면 위 칸이 흩어져 3일짜리가 앉을 자리를 못 찾는다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("solo1", startDay: 1), over: [1], into: &table)
        spread(item("solo2", startDay: 2), over: [2], into: &table)
        spread(item("span", startDay: 1), over: [1, 2, 3], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)

        #expect(lane(of: "span", day: 1, in: layout) == 0)
        #expect(lane(of: "span", day: 2, in: layout) == 0)
        #expect(lane(of: "span", day: 3, in: layout) == 0)
    }

    @Test func aLaneIsReservedOnlyForTheDaysTheEventCovers() {
        // 연속 일정이 지나가지 않는 날에서는 그 칸을 다른 항목이 쓸 수 있어야 한다 —
        // 안 그러면 격자에 빈 줄만 늘어난다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("span", startDay: 1), over: [1, 2], into: &table)
        spread(item("later", startDay: 5), over: [5], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)

        #expect(lane(of: "later", day: 5, in: layout) == 0)
    }

    @Test func twoOverlappingSpansStack() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1, 2, 3], into: &table)
        spread(item("b", startDay: 2), over: [2, 3, 4], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)

        #expect(lane(of: "a", day: 2, in: layout) != lane(of: "b", day: 2, in: layout))
        // 각자는 자기 날들에서 칸이 일정해야 한다.
        #expect(lane(of: "b", day: 2, in: layout) == lane(of: "b", day: 4, in: layout))
    }

    @Test func emptyLanesAreKeptSoLaterLanesStayAligned() {
        // 3일 칸 0을 연속 일정이 차지하면, 그 일정이 없는 1일의 칸 0은 비어 있어야
        // 아래 칸들이 옆 셀과 같은 줄에 남는다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("span", startDay: 2), over: [2, 3], into: &table)
        spread(item("only1", startDay: 1), over: [1], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)

        #expect(layout.lanes(forDay: 1).count == 3)
        #expect(layout.lanes(forDay: 2).count == 3)
    }

    // MARK: - 오버플로

    @Test func itemsBeyondTheLaneCountBecomeOverflowOnEveryDayTheyCover() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1, 2], into: &table)
        spread(item("b", startDay: 1, hour: 10), over: [1, 2], into: &table)
        spread(item("c", startDay: 1, hour: 11), over: [1, 2], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 2)

        #expect(layout.overflow(forDay: 1) == 1)
        #expect(layout.overflow(forDay: 2) == 1)
    }

    @Test func overflowIsCountedPerDayNotPerWeek() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1], into: &table)
        spread(item("b", startDay: 1, hour: 10), over: [1], into: &table)
        spread(item("c", startDay: 3), over: [3], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 1)

        #expect(layout.overflow(forDay: 1) == 1)
        #expect(layout.overflow(forDay: 3) == 0)
    }

    @Test func zeroSlotsPushEverythingIntoOverflow() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1, 2], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 0)

        #expect(layout.overflow(forDay: 1) == 1)
        #expect(layout.overflow(forDay: 2) == 1)
        #expect(layout.lanes(forDay: 1).isEmpty)
    }

    // MARK: - 경계

    @Test func daysOutsideTheDisplayedMonthAreSkipped() {
        // 주의 앞뒤 빈 칸(nil)에는 어떤 칸 배열도 만들지 않는다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1], into: &table)
        let partial: [Int?] = [nil, nil, 1, 2, 3, 4, 5]

        let layout = MonthWeekPacker.pack(days: partial, itemsByDay: table, slots: 2)

        #expect(layout.lanes.keys.sorted() == [1, 2, 3, 4, 5])
    }

    @Test func anEmptyWeekProducesNothing() {
        let layout = MonthWeekPacker.pack(days: [nil, nil], itemsByDay: [:], slots: 3)

        #expect(layout == .empty)
    }

    @Test func packingIsDeterministic() {
        // 같은 조건의 두 항목 순서가 갱신마다 뒤집히면 위젯이 이유 없이 깜빡인다.
        var first: [Int: [WidgetCalendarItem]] = [:]
        spread(item("alpha", startDay: 1), over: [1], into: &first)
        spread(item("zulu", startDay: 1), over: [1], into: &first)

        var second: [Int: [WidgetCalendarItem]] = [:]
        spread(item("zulu", startDay: 1), over: [1], into: &second)
        spread(item("alpha", startDay: 1), over: [1], into: &second)

        let left = MonthWeekPacker.pack(days: week, itemsByDay: first, slots: 3)
        let right = MonthWeekPacker.pack(days: week, itemsByDay: second, slots: 3)

        #expect(left.lanes(forDay: 1).map { $0?.id } == right.lanes(forDay: 1).map { $0?.id })
        #expect(left.lanes(forDay: 1).first??.id == "alpha")
    }

    @Test func allDayEventsOutrankTimedOnesAtTheSameSpan() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("timed", kind: .timedEvent, startDay: 1, hour: 8), over: [1], into: &table)
        spread(item("allDay", kind: .allDayEvent, startDay: 1, hour: 12), over: [1], into: &table)
        spread(item("reminder", kind: .reminder, startDay: 1, hour: 6), over: [1], into: &table)

        let layout = MonthWeekPacker.pack(days: week, itemsByDay: table, slots: 3)

        #expect(layout.lanes(forDay: 1).map { $0?.id } == ["allDay", "timed", "reminder"])
    }

    // MARK: - 가로 구간
    //
    // 연속 일정은 셀마다 반복되는 게 아니라 **여러 칸을 가로지르는 막대 하나**여야 한다.
    // 셀 단위로 그리면 3일짜리 일정이 제목까지 세 번 반복된다.

    private func runs(_ table: [Int: [WidgetCalendarItem]], slots: Int, lane: Int = 0) -> [MonthWeekRun] {
        MonthWeekPacker.runs(
            week: week,
            layout: MonthWeekPacker.pack(days: week, itemsByDay: table, slots: slots),
            lane: lane
        )
    }

    @Test func consecutiveDaysOfOneEventBecomeASingleRun() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("trip", startDay: 2), over: [2, 3, 4], into: &table)

        let laid = runs(table, slots: 2)
        let trip = laid.first { $0.item?.id == "trip" }

        #expect(trip?.startColumn == 1)
        #expect(trip?.length == 3)
        #expect(trip?.isSpanning == true)
    }

    @Test func differentEventsInTheSameLaneStaySeparateRuns() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1, 2], into: &table)
        spread(item("b", startDay: 3), over: [3, 4], into: &table)

        let laid = runs(table, slots: 2).filter { $0.item != nil }

        #expect(laid.count == 2)
        #expect(laid.map(\.length) == [2, 2])
    }

    @Test func emptyStretchesBecomeRunsSoLaterBarsStayAligned() {
        // 빈 구간도 자리를 차지해야 뒤 막대가 제 열에서 시작한다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("late", startDay: 5), over: [5, 6], into: &table)

        let laid = runs(table, slots: 2)
        let late = laid.first { $0.item?.id == "late" }

        #expect(late?.startColumn == 4)
        #expect(laid.first?.item == nil)
        #expect(laid.first?.length == 4)
    }

    @Test func runsAlwaysCoverTheWholeWeek() {
        // 구간 길이의 합이 열 수와 다르면 막대 폭이 어긋나 격자에서 밀려난다.
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 2), over: [2, 3], into: &table)
        spread(item("b", startDay: 6), over: [6], into: &table)

        for lane in 0..<2 {
            let total = runs(table, slots: 2, lane: lane).reduce(0) { $0 + $1.length }
            #expect(total == week.count)
        }
    }

    @Test func aSingleDayItemIsNotMarkedAsSpanning() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("solo", startDay: 3), over: [3], into: &table)

        let solo = runs(table, slots: 2).first { $0.item?.id == "solo" }

        #expect(solo?.length == 1)
        #expect(solo?.isSpanning == false)
    }

    @Test func daysOutsideTheMonthJoinTheEmptyRun() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1], into: &table)
        let partial: [Int?] = [nil, nil, 1, 2, 3, 4, 5]

        let laid = MonthWeekPacker.runs(
            week: partial,
            layout: MonthWeekPacker.pack(days: partial, itemsByDay: table, slots: 2),
            lane: 0
        )

        // 앞의 빈 칸 두 개와 1일 항목은 서로 다른 구간이어야 한다.
        #expect(laid.first?.item == nil)
        #expect(laid.first?.length == 2)
        #expect(laid.reduce(0) { $0 + $1.length } == partial.count)
    }

    @Test func aLaneBeyondTheSlotCountIsAllEmpty() {
        var table: [Int: [WidgetCalendarItem]] = [:]
        spread(item("a", startDay: 1), over: [1], into: &table)

        let laid = runs(table, slots: 1, lane: 5)

        #expect(laid.count == 1)
        #expect(laid.first?.item == nil)
        #expect(laid.first?.length == week.count)
    }
}
