//
//  DayTimelineLayoutTests.swift
//  cueTests
//

import CoreGraphics
import Foundation
import Testing
import UIKit
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
        columnWidth: CGFloat = 100,
        gap: CGFloat = 0
    ) -> DayTimelineLayout.Metrics {
        DayTimelineLayout.Metrics(
            columnWidth: columnWidth,
            height: 240,
            minimumHeight: 10,
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

    /// 폭은 컬럼 패킹이 정하므로 제목 측정을 주입할 필요가 없다 — 결정론적이다.
    private func layout(
        _ items: [WidgetCalendarItem],
        _ metrics: DayTimelineLayout.Metrics? = nil
    ) -> DayTimelineLayoutResult {
        DayTimelineLayout.layout(
            for: items, day: day,
            metrics: metrics ?? self.metrics(),
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

    @Test func aLongEventReusesAColumnFreedByAnEarlierItem() {
        // `early`가 0번 칸을 잡고 `mid`는 겹치므로 1번으로 간다. `shift`는 10시 시작이라
        // `early`(9시, 최소 높이만큼만 차지)와 안 겹치므로 **0번 칸을 다시 쓴다.**
        // 그리디 컬럼 배정이 "비워진 왼쪽 칸"을 재사용한다는 뜻이다.
        let result = layout([
            reminder("early", at(9)),
            reminder("mid", at(9, 30)),
            event("shift", at(10), at(19))
        ])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(isClose(byID["shift"]?.x ?? -1, 0))
        #expect((byID["mid"]?.x ?? 0) > 0)
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

        // 관심사는 **아무도 버려지지 않는가**다. 폭이 얇게 유지되는지는
        // `overlappingBlocksStayNarrowEnoughToNeverCoverTheNextColumn`이 따로 본다.
        #expect(result.blocks.count == 3)
        #expect(result.hidden == 0)
    }

    @Test func aSoloBlockTakesTheWholeColumn() {
        // 겹치는 게 없으면 열 폭을 다 쓴다 — 제목 길이는 보지 않는다.
        let result = layout([event("alone", at(9), at(10))])

        #expect(isClose(result.blocks[0].width, 100))
        #expect(isClose(result.blocks[0].x, 0))
    }

    /// 어떤 두 블록도 **겹치지 않는다** — 세로가 겹치면 가로는 반드시 벌어져 있어야 한다.
    ///
    /// 후보 자리에 "이미 놓인 블록의 오른쪽 끝"만 넣으면 사이 빈틈을 못 본다. 서로
    /// 겹치지 않는 두 블록이 각각 x=0에 놓인 뒤, 둘 다와 겹치는 세 번째가 들어갈 자리를
    /// 못 찾아 결국 위로 포개진다(레퍼런스는 같은 구간을 촘촘히 나란히 세운다).
    @Test func placedBlocksNeverOverlapEachOther() {
        let result = layout([
            event("a", at(8), at(8, 30)),
            event("b", at(8, 30), at(9)),
            event("c", at(8, 15), at(8, 45)),
            event("d", at(8), at(9)),
            event("e", at(8, 40), at(9, 10))
        ], metrics(columnWidth: 100))

        for (i, lhs) in result.blocks.enumerated() {
            for rhs in result.blocks.dropFirst(i + 1) {
                let verticallyOverlaps =
                    lhs.startFraction < rhs.endFraction && rhs.startFraction < lhs.endFraction
                guard verticallyOverlaps else { continue }
                let horizontallyOverlaps =
                    lhs.x < rhs.x + rhs.width && rhs.x < lhs.x + lhs.width
                #expect(!horizontallyOverlaps, "\(lhs.id)와 \(rhs.id)가 겹친다")
            }
        }
    }

    /// 어떤 블록도 **자기 열을 넘지 않는다.**
    ///
    /// 조사해 보니 FullCalendar·react-big-calendar 등 어떤 캘린더 구현도 날짜 열을 넘기지
    /// 않는다. 날짜 열은 의미 경계라, 넘어가면 어느 날 일정인지 모호해진다.
    /// 실기기에서도 "출근 전 에어컨 송풍 30분 후 끄기"가 31일 일정을 통째로 가렸다.
    @Test func noBlockEverLeavesItsColumn() {
        let result = layout([
            event("solo", at(9), at(10)),
            event("a", at(14), at(16)),
            event("b", at(14, 30), at(16)),
            event("c", at(15), at(16))
        ], metrics(columnWidth: 100))

        #expect(result.blocks.allSatisfy { $0.x + $0.width <= 100.0001 })
    }

    /// **확장** — 오른쪽 칸이 자기 시간대에 비어 있으면 흡수한다.
    ///
    /// 이게 없으면 3일 위젯처럼 열이 좁을 때(104pt) 3컬럼 그룹의 단독 블록이 35pt로 렌더돼
    /// 글자가 안 읽힌다. 표준 알고리즘의 `ExpandEvent` 단계다.
    @Test func aBlockAbsorbsFreeColumnsToItsRight() {
        // a·b·c가 9~10시에 세 겹 → 3컬럼. d는 11~12시라 셋 중 누구와도 안 겹친다.
        // d는 0번 칸에 배정된 뒤 오른쪽 두 칸이 비어 있으므로 전부 흡수해 열 폭을 다 쓴다.
        let result = layout([
            event("a", at(9), at(10)),
            event("b", at(9), at(10)),
            event("c", at(9), at(10)),
            event("d", at(11), at(12))
        ])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        // a·b·c는 셋이 겹치므로 1/3씩.
        #expect(isClose(byID["a"]?.width ?? 0, 100.0 / 3))
        // d는 다른 그룹이라 통째로 쓴다.
        #expect(isClose(byID["d"]?.width ?? 0, 100))
    }

    /// 확장은 **첫 막힌 칸에서 멈춘다** — 건너뛰어 더 먼 빈 칸을 잡지 않는다.
    @Test func expansionStopsAtTheFirstBlockedColumn() {
        // a(0번), b(1번), c(2번)가 같은 시간대에 세 겹.
        // d는 a와만 겹치고 b·c와는 안 겹치는데, 1번 칸이 막혀 있으면 거기서 멈춰야 한다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9), at(12)),
            event("c", at(9), at(12)),
            event("d", at(9), at(12))
        ])

        // 네 겹이므로 각자 1/4. 아무도 옆 칸을 흡수하지 못한다.
        #expect(result.blocks.allSatisfy { isClose($0.width, 25) })
    }

    @Test func narrowBlocksSurviveAsColourBarsInsteadOfBeingDropped() {
        // 제목이 못 들어갈 만큼 좁아져도 **버리지 않는다** — 색 막대로 남긴다.
        // 예전엔 최소 폭 미달이면 통째로 버려서, 겹침이 깊은 오전이 비어 보였다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 10), at(12)),
            event("c", at(9, 20), at(12)),
            event("d", at(9, 30), at(12))
        ], metrics())

        #expect(result.blocks.count == 4)
        #expect(result.hidden == 0)
        // 네 겹 → 각자 1/4. 제목은 안 들어가도 막대는 선다.
        #expect(result.blocks.allSatisfy { isClose($0.width, 25) })
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
        // 오전 혼잡과 다른 그룹이라 열 폭을 온전히 쓴다.
        #expect(isClose(byID["afternoon"]?.width ?? 0, 100))
    }

    // MARK: - 결정론

    @Test func layoutIsDeterministicForIdenticalRanges() {
        // 같은 구간 두 개의 순서가 렌더마다 뒤집히면 위젯이 이유 없이 깜빡인다.
        let first = layout([event("b", at(9), at(10)), event("a", at(9), at(10))]).blocks
        let second = layout([event("a", at(9), at(10)), event("b", at(9), at(10))]).blocks

        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map(\.x) == second.map(\.x))
    }

    /// 겹침이 깊어도 항목을 **버리지 않는다** — 좁으면 색 막대로라도 남긴다.
    ///
    /// 예전엔 최소 폭이 안 나오면 그 자리를 건너뛰고 결국 항목을 버렸다. 오전처럼 여러 개가
    /// 겹치는 구간이 통째로 비어 보였다(실기기에서 29일 오전 7개가 전부 사라졌다).
    /// 레퍼런스(캘린더 앱)는 같은 구간에서 2~4pt짜리 막대까지 그린다.
    @Test func denselyOverlappingItemsSurviveAsThinBars() {
        // 열 폭 100pt에 최소 폭 20pt — 여덟 겹이면 한 칸이 12.5pt로 하한에 못 미친다.
        var items: [WidgetCalendarItem] = []
        for index in 0..<8 {
            items.append(event("dense\(index)", at(8, index * 5), at(9, index * 5)))
        }

        let result = layout(items, metrics(columnWidth: 100))

        #expect(result.blocks.count == items.count)
        #expect(result.hidden == 0)
    }

    /// 충돌 그룹은 **서로 독립**이다 — 오전의 혼잡이 오후 블록의 폭을 깎지 않는다.
    ///
    /// 예전엔 묶음 전체의 최대 겹침을 모든 블록에 일괄 적용했다. 오전에 짧은 일정이 몰린
    /// 날은 그 최대값이 5~6이 되고, 10~19시에 걸친 "출근" 블록까지 그만큼 눌려 최소 폭에
    /// 못 미쳐 통째로 버려졌다(실기기에서 3일 내내 출근이 사라졌다).
    @Test func aCrowdedMorningDoesNotShrinkAnUnrelatedLaterEvent() {
        var items: [WidgetCalendarItem] = []
        // 오전 8~9시에 여섯 겹.
        for index in 0..<6 {
            items.append(event("morning\(index)", at(8), at(9)))
        }
        // 오후 단독 일정 — 오전 혼잡과 시간이 전혀 겹치지 않는다.
        items.append(event("afternoon", at(14), at(16)))

        let result = layout(items, metrics(columnWidth: 104))
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(result.blocks.count == 7)
        // 다른 그룹이므로 열 폭을 온전히 쓴다.
        #expect(isClose(byID["afternoon"]?.width ?? 0, 104))
    }

    // MARK: - 치수

    /// 제목을 그릴지 색 막대만 남길지 가르는 임계값 — **실제로 그려지는 글자 크기** 기준.
    ///
    /// 폭 자체는 컬럼 패킹이 정하므로 예산 계산이 없다. 여기서 답할 건 하나뿐이다:
    /// 주어진 폭에 제목 한 글자가 들어가는가. 이 값이 렌더와 어긋나면 "그릴 수 있다"고
    /// 판정한 블록에 글자가 잘려 나오거나, 들어갈 제목이 색 막대로 밀려난다.
    @Test func barOnlyWidthFitsTheLeadingMarkAndOneGlyph() {
        let glyph = DayTimelineMetrics.titleFont.pointSize * DayTimelineMetrics.titleScale
        // 일정은 색 막대, 할일은 동그라미가 앞에 선다 — 넓은 쪽을 기준으로 잡아야
        // 어느 종류든 글자가 밀리지 않는다.
        let leading = max(
            DayTimelineMetrics.leadingBarWidth,
            DayTimelineMetrics.markerSize + DayTimelineMetrics.markerGap
        )

        #expect(DayTimelineMetrics.barOnlyWidth >= leading + glyph)
        // 두 글자를 요구하지는 않는다 — 그러면 한 글자는 들어갈 칸까지 막대로 밀려난다.
        #expect(DayTimelineMetrics.barOnlyWidth < leading + glyph * 2)
    }

    /// 최소 높이는 **축소된 줄높이**를 따른다 — 뷰가 `titleScale`로 줄여 그리기 때문이다.
    @Test func minimumHeightMatchesTheScaledLineHeight() {
        let scaled = DayTimelineMetrics.titleFont.lineHeight * DayTimelineMetrics.titleScale

        #expect(DayTimelineMetrics.minimumHeight >= scaled)
        #expect(DayTimelineMetrics.minimumHeight < scaled + 1)
    }

    /// 항목이 하나도 없어도 터지지 않는다 — 종일만 있는 날이 실제로 흔하다.
    @Test func emptyDayProducesNoBlocks() {
        let result = layout([])

        #expect(result.blocks.isEmpty)
        #expect(result.hidden == 0)
    }

    /// **완전히 같은 구간**이 여러 개 — 컬럼 배정이 이들을 각자 다른 칸에 놓아야 한다.
    ///
    /// 그리디 배정이 "겹치지 않는 첫 칸"을 찾는데, 전부 같은 구간이면 매번 새 칸이 열린다.
    /// 이 경우가 깨지면 반복 일정이 여러 개인 날에 블록이 하나로 포개진다.
    @Test func identicalSpansEachGetTheirOwnColumn() {
        let result = layout([
            event("a", at(9), at(10)),
            event("b", at(9), at(10)),
            event("c", at(9), at(10))
        ])
        let xs = Set(result.blocks.map { $0.x })

        #expect(result.blocks.count == 3)
        // 셋이 서로 다른 x — 같은 자리에 포개지지 않는다.
        #expect(xs.count == 3)
        #expect(result.blocks.allSatisfy { isClose($0.width, 100.0 / 3) })
    }

    /// 종일 항목만 있는 날 — 시간표에는 아무것도 그리지 않는다(별도 스트립이 맡는다).
    @Test func aDayWithOnlyAllDayItemsDrawsNothingOnTheTimeline() {
        func allDay(_ id: String) -> WidgetCalendarItem {
            WidgetCalendarItem(
                id: id, title: id, start: day, end: day.addingTimeInterval(86_400),
                kind: .allDayEvent, colorHex: nil, isHighPriority: false
            )
        }
        let result = layout([allDay("holiday"), allDay("vacation")])

        #expect(result.blocks.isEmpty)
        #expect(result.hidden == 0)
    }

    @Test func degenerateHeightNeverProducesInvalidFractions() {
        // GeometryReader가 첫 렌더에 0을 주는 순간이 있다.
        let zeroHeight = DayTimelineLayout.Metrics(
            columnWidth: 100, height: 0,
            minimumHeight: 10, gap: 0
        )
        let result = layout([event("a", at(9), at(10))], zeroHeight)

        #expect(result.blocks.allSatisfy { $0.startFraction >= 0 && $0.endFraction <= 1 })
    }
}
