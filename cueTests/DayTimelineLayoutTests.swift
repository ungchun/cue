//
//  DayTimelineLayoutTests.swift
//  cueTests
//

import CoreGraphics
import Foundation
import Testing
@testable import cue

/// 1일·3일 위젯 시간표의 배치 계산.
///
/// 세로는 하루를 `0...1`로 본 비율, 가로는 pt다. 치수와 제목 폭 측정을 모두 주입받으므로
/// UIKit·위젯 높이와 무관하게 결정론적으로 검증할 수 있다.
struct DayTimelineLayoutTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private var day: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 27))!
    }

    private func at(_ hour: Int, _ minute: Int = 0, dayOffset: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 27 + dayOffset, hour: hour, minute: minute)
        )!
    }

    /// 높이 240pt = 1시간당 10pt. 최소 높이도 10pt라 "1시간"이 최소 단위가 돼 계산이 읽기 쉽다.
    private func metrics(
        availableWidth: CGFloat = 300,
        columnWidth: CGFloat = 100,
        minimumWidth: CGFloat = 20,
        gap: CGFloat = 0
    ) -> DayTimelineLayout.Metrics {
        DayTimelineLayout.Metrics(
            availableWidth: availableWidth,
            columnWidth: columnWidth,
            height: 240,
            minimumHeight: 10,
            minimumWidth: minimumWidth,
            gap: gap
        )
    }

    private func event(_ id: String, _ from: Date, _ to: Date) -> WidgetCalendarItem {
        WidgetCalendarItem(
            id: id, title: id, start: from, end: to,
            kind: .timedEvent, colorHex: nil, isHighPriority: false
        )
    }

    private func reminder(_ id: String, _ at: Date) -> WidgetCalendarItem {
        WidgetCalendarItem(
            id: id, title: id, start: at, end: at,
            kind: .reminder, colorHex: nil, isHighPriority: false
        )
    }

    /// 제목 폭은 기본 60pt로 고정 — 폭 상한 로직만 남기고 텍스트 측정을 배제한다.
    private func layout(
        _ items: [WidgetCalendarItem],
        _ metrics: DayTimelineLayout.Metrics? = nil,
        preferredWidth: @escaping (WidgetCalendarItem) -> CGFloat = { _ in 60 }
    ) -> DayTimelineLayoutResult {
        DayTimelineLayout.layout(
            for: items, day: day,
            metrics: metrics ?? self.metrics(),
            preferredWidth: preferredWidth,
            calendar: calendar
        )
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.0001 }
    private func isClose(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { abs(lhs - rhs) < 0.01 }

    // MARK: - 시간 → 비율

    @Test func mapsHoursToFractionsOfTheDay() {
        let blocks = layout([event("a", at(6), at(12))]).blocks

        #expect(blocks.count == 1)
        #expect(isClose(blocks[0].startFraction, 6.0 / 24))
        #expect(isClose(blocks[0].endFraction, 12.0 / 24))
    }

    @Test func clipsEventsSpillingInFromThePreviousDay() {
        let blocks = layout([event("overnight", at(22, dayOffset: -1), at(8))]).blocks

        #expect(isClose(blocks[0].startFraction, 0))
        #expect(isClose(blocks[0].endFraction, 8.0 / 24))
    }

    @Test func clipsEventsRunningIntoTheNextDay() {
        let blocks = layout([event("overnight", at(21), at(3, dayOffset: 1))]).blocks

        #expect(isClose(blocks[0].startFraction, 21.0 / 24))
        #expect(isClose(blocks[0].endFraction, 1))
    }

    @Test func dropsEventsOutsideTheDay() {
        #expect(layout([event("tomorrow", at(9, dayOffset: 1), at(10, dayOffset: 1))]).blocks.isEmpty)
    }

    @Test func excludesAllDayItemsBecauseTheyRenderInTheirOwnStrip() {
        let allDay = WidgetCalendarItem(
            id: "holiday", title: "holiday", start: day, end: day.addingTimeInterval(86_400),
            kind: .allDayEvent, colorHex: nil, isHighPriority: false
        )
        #expect(layout([allDay]).blocks.isEmpty)
    }

    // MARK: - 최소 높이

    @Test func givesZeroLengthItemsAMinimumVisibleHeight() {
        // 미리알림은 시작=끝이라 그대로 두면 높이 0으로 사라진다.
        let blocks = layout([reminder("r", at(19, 30))]).blocks

        #expect(blocks.count == 1)
        #expect(isClose((blocks[0].endFraction - blocks[0].startFraction) * 240, 10))
    }

    @Test func minimumHeightNearMidnightShiftsUpInsteadOfOverflowing() {
        let blocks = layout([reminder("r", at(23, 55))]).blocks

        #expect(isClose(blocks[0].endFraction, 1))
        #expect(isClose((blocks[0].endFraction - blocks[0].startFraction) * 240, 10))
    }

    // MARK: - 가로 배치

    @Test func nonOverlappingBlocksAllStartAtTheLeftEdge() {
        // 겹치지 않으면 언제나 열 왼쪽에서 시작해 제목을 온전히 보여준다.
        let blocks = layout([event("a", at(9), at(10)), event("b", at(12), at(13))]).blocks

        #expect(blocks.allSatisfy { isClose($0.x, 0) })
    }

    @Test func touchingBlocksDoNotCountAsOverlapping() {
        // 09:00–10:00 과 10:00–11:00 은 경계만 맞닿을 뿐 겹치지 않는다.
        let blocks = layout([event("a", at(9), at(10)), event("b", at(10), at(11))]).blocks

        #expect(blocks.allSatisfy { isClose($0.x, 0) })
    }

    @Test func overlappingBlocksStackToTheRight() {
        let result = layout([event("a", at(9), at(12)), event("b", at(10), at(11))])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(isClose(byID["a"]?.x ?? -1, 0))
        // 두 개가 겹치므로 폭 예산은 열 폭의 절반(50) — b는 그 오른쪽에 붙는다.
        #expect(isClose(byID["a"]?.width ?? 0, 50))
        #expect(isClose(byID["b"]?.x ?? -1, 50))
    }

    @Test func eventsArePlacedBeforeRemindersSoLongEventsKeepTheLeftEdge() {
        // 시각 순으로만 놓으면 오전에 몰린 짧은 미리알림이 왼쪽을 차지해, 하루를 관통하는
        // 일정이 오른쪽 끝으로 밀린다. 레퍼런스처럼 일정이 기둥으로 서야 한다.
        let result = layout([
            reminder("early", at(9)),
            reminder("mid", at(9, 30)),
            event("shift", at(10), at(19))
        ])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(isClose(byID["shift"]?.x ?? -1, 0))
        #expect((byID["early"]?.x ?? 0) > 0 || (byID["mid"]?.x ?? 0) > 0)
    }

    // MARK: - 폭 예산

    @Test func overlappingBlocksShareTheColumnWidth() {
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 30), at(12)),
            event("c", at(10), at(12))
        ])

        // 세 겹 → 각자 열 폭의 1/3. 제목이 원하는 60pt보다 좁아진다.
        #expect(result.blocks.allSatisfy { isClose($0.width, 100.0 / 3) })
        #expect(result.hidden == 0)
    }

    @Test func gapIsTakenOutOfTheSharedBudgetSoTheLastBlockStillFits() {
        // 틈을 예산에서 빼지 않으면 마지막 블록이 경계 밖으로 밀려 통째로 버려진다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 30), at(12)),
            event("c", at(10), at(12))
        ], metrics(gap: 2))

        #expect(result.blocks.count == 3)
        #expect(result.hidden == 0)
        #expect(result.blocks.allSatisfy { $0.x + $0.width <= 100.0001 })
    }

    @Test func aSoloBlockMayGrowPastItsColumnIntoTheNextDay() {
        // 겹치는 게 없으면 제목 길이만큼 옆 날짜 열까지 넘어간다(레퍼런스의 긴 미리알림).
        let result = layout([event("alone", at(9), at(10))], preferredWidth: { _ in 200 })

        #expect(isClose(result.blocks[0].width, 200))
    }

    @Test func overlappingBlocksNeverLeaveTheirColumn() {
        // 겹치는 블록까지 옆 열로 넘어가면 그 열의 블록 위를 덮어 둘 다 못 읽게 된다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 30), at(12)),
            event("c", at(10), at(12))
        ], preferredWidth: { _ in 500 })

        #expect(result.blocks.allSatisfy { $0.x + $0.width <= 100.0001 })
    }

    @Test func blocksNeverGoBelowTheMinimumWidth() {
        // 예산이 최소 폭보다 작아져도(아주 깊은 겹침) 그리는 블록은 최소 폭을 지킨다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 10), at(12)),
            event("c", at(9, 20), at(12)),
            event("d", at(9, 30), at(12))
        ], metrics(minimumWidth: 40))

        #expect(result.blocks.allSatisfy { $0.width >= 40 })
    }

    @Test func itemsWithNoRoomLeftAreCountedInsteadOfDrawn() {
        // 최소 폭조차 안 나오면 알아볼 수 없는 조각을 그리는 대신 개수만 알린다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 10), at(12)),
            event("c", at(9, 20), at(12)),
            event("d", at(9, 30), at(12))
        ], metrics(minimumWidth: 45))

        #expect(result.blocks.count == 2)
        #expect(result.hidden == 2)
        #expect(result.blocks.allSatisfy { $0.x + $0.width <= 100.0001 })
    }

    @Test func aLaterFreeSlotStillStartsAtTheLeftEdge() {
        // 오전이 꽉 찼어도 오후의 단독 일정은 왼쪽에서 온전한 폭으로 시작해야 한다.
        let result = layout([
            event("a", at(9), at(11)),
            event("b", at(9, 30), at(11)),
            event("afternoon", at(15), at(16))
        ])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(isClose(byID["afternoon"]?.x ?? -1, 0))
        #expect(isClose(byID["afternoon"]?.width ?? 0, 60))
    }

    // MARK: - 결정론

    @Test func layoutIsDeterministicForIdenticalRanges() {
        // 같은 구간 두 개의 순서가 렌더마다 뒤집히면 위젯이 이유 없이 깜빡인다.
        let first = layout([event("b", at(9), at(10)), event("a", at(9), at(10))]).blocks
        let second = layout([event("a", at(9), at(10)), event("b", at(9), at(10))]).blocks

        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.x) == second.map(\.x))
    }

    @Test func degenerateHeightNeverProducesInvalidFractions() {
        // GeometryReader가 첫 렌더에 0을 주는 순간이 있다.
        let zeroHeight = DayTimelineLayout.Metrics(
            availableWidth: 300, columnWidth: 100, height: 0,
            minimumHeight: 10, minimumWidth: 20, gap: 0
        )
        let result = layout([event("a", at(9), at(10))], zeroHeight)

        #expect(result.blocks.allSatisfy { $0.startFraction >= 0 && $0.endFraction <= 1 })
    }
}
