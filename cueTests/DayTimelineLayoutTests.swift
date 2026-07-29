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

        // 관심사는 **아무도 버려지지 않는가**다. 폭이 얇게 유지되는지는
        // `overlappingBlocksStayNarrowEnoughToNeverCoverTheNextColumn`이 따로 본다.
        #expect(result.blocks.count == 3)
        #expect(result.hidden == 0)
    }

    @Test func aSoloBlockGrowsToItsTitleWithinTheColumn() {
        // 겹치는 게 없으면 제목 길이만큼 넓어진다 — 단, 자기 열 폭 안에서.
        let result = layout([event("alone", at(9), at(10))], preferredWidth: { _ in 80 })

        #expect(isClose(result.blocks[0].width, 80))
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
        ], metrics(columnWidth: 100, minimumWidth: 15), preferredWidth: { _ in 30 })

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

    /// 단독 블록이라도 **자기 열을 넘지 않는다.**
    ///
    /// 충돌 판정은 같은 날짜 열 안에서만 이뤄지므로(배치가 날짜별로 돈다) 옆 열에 뭐가
    /// 있는지 알 수 없다. 넘어가면 그쪽 블록을 덮는다 — 실기기에서 "출근 전 에어컨 송풍
    /// 30분 후 끄기"가 31일 일정을 가렸고, 상한을 1.5배로 낮춰도 52pt를 침범해 그대로였다.
    @Test func aSoloBlockNeverLeavesItsColumn() {
        let result = layout(
            [event("veryLongTitle", at(9), at(10))],
            metrics(availableWidth: 300, columnWidth: 100),
            preferredWidth: { _ in 900 }
        )

        #expect(result.blocks[0].width <= 100.0001)
    }

    @Test func overlappingBlocksStayWithinTheirColumn() {
        // 겹치는 블록은 폭을 자기 열 몫으로 나눠 갖고, 위치도 열 안에 머문다.
        // 제목이 아무리 길어도(500pt를 원해도) 열을 넘지 않는다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 30), at(12)),
            event("c", at(10), at(12))
        ], preferredWidth: { _ in 500 })

        #expect(result.blocks.count == 3)
        // 셋이 겹치므로 각자 열 폭의 3분의 1 남짓.
        #expect(result.blocks.allSatisfy { $0.width <= 100.0 / 3 + 0.0001 })
        #expect(result.blocks.allSatisfy { $0.x + $0.width <= 100.0001 })
    }

    @Test func itemsWithNoRoomLeftStillGetAThinBar() {
        // 최소 폭이 안 나와도 **버리지 않는다** — 좁으면 색 막대로 남긴다.
        // 예전엔 여기서 개수만 알렸는데, 겹침이 깊은 오전이 통째로 비어 보였다.
        let result = layout([
            event("a", at(9), at(12)),
            event("b", at(9, 10), at(12)),
            event("c", at(9, 20), at(12)),
            event("d", at(9, 30), at(12))
        ], metrics(minimumWidth: 45))

        #expect(result.blocks.count == 4)
        #expect(result.hidden == 0)
        // 좁아진 뒤에도 폭은 자기 열 몫을 넘지 않는다.
        #expect(result.blocks.allSatisfy { $0.width <= 100.0001 })
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

        let result = layout(items, metrics(columnWidth: 100, minimumWidth: 20))

        #expect(result.blocks.count == items.count)
        #expect(result.hidden == 0)
    }

    /// 긴 일정은 **짧은 일정보다 먼저** 자리를 잡아 왼쪽 넓은 자리를 쓴다.
    ///
    /// 일정끼리 시각 순으로 놓으면 8~10시 짧은 일정들이 왼쪽을 선점하고, 10시에 시작하는
    /// 긴 일정은 남은 좁은 틈으로 밀려 최소 폭 언저리만 받는다 — 폭이 남아 있는데도 제목이
    /// `...`로만 남는다(실기기에서 21pt까지 눌렸다).
    @Test func longEventTakesTheLeftEdgeBeforeShorterOnes() {
        let result = layout([
            event("short1", at(8), at(9)),
            event("short2", at(8, 30), at(9, 30)),
            event("long", at(10), at(19))
        ])
        let byID = Dictionary(uniqueKeysWithValues: result.blocks.map { ($0.id, $0) })

        #expect(isClose(byID["long"]?.x ?? -1, 0))
    }

    /// 긴 일정은 **자기 구간의 겹침**만큼만 좁아진다.
    ///
    /// 예전엔 묶음 전체의 최대 겹침을 모든 블록에 일괄 적용했다. 오전에 짧은 일정이 몰린
    /// 날은 그 최대값이 5~6이 되고, 10~19시에 걸친 "출근" 블록까지 그만큼 눌려 최소 폭에
    /// 못 미쳐 통째로 버려졌다(실기기에서 3일 내내 출근이 사라졌다).
    @Test func longEventKeepsItsWidthDespiteACrowdedMorning() {
        var items: [WidgetCalendarItem] = []
        // 오전 8~10시에 여섯 겹 — 서로 조금씩 어긋나게 겹친다.
        for index in 0..<6 {
            items.append(
                event("morning\(index)", at(8, index * 10), at(9, index * 10))
            )
        }
        // 그 뒤로 이어지는 긴 일정 — 오전 혼잡과는 10시 이후로만 스친다.
        items.append(event("long", at(10), at(19)))

        let result = layout(items, metrics(columnWidth: 104, minimumWidth: 23))

        #expect(result.blocks.contains { $0.id == "long" })
    }

    // MARK: - 치수 예산

    /// 블록 왼쪽 색 막대는 **제목이 쓸 수 있는 폭에서 먼저 빠진다.**
    ///
    /// 뷰가 막대를 그리고 그만큼 제목을 들여쓰므로, 예산이 이를 모르면 계산상 "들어간다"고
    /// 판정한 제목이 실제로는 막대 폭만큼 잘린다. 두 값은 항상 같이 움직여야 한다.
    @Test func preferredWidthReservesRoomForTheLeadingColorBar() {
        let item = WidgetCalendarItem(
            id: "a", title: "회의", start: at(9), end: at(10),
            kind: .timedEvent, colorHex: nil, isHighPriority: false
        )
        let width = DayTimelineMetrics.preferredWidth(for: item)
        let titleOnly = ("회의" as NSString)
            .size(withAttributes: [.font: DayTimelineMetrics.titleFont]).width
            * DayTimelineMetrics.titleScale

        #expect(width >= titleOnly + DayTimelineMetrics.leadingBarWidth)
    }

    /// 제목 폭은 **축소된 글자 크기**로 잰다.
    ///
    /// 뷰가 `titleScale`로 줄여 그리므로, 측정에 배율을 안 곱하면 실제보다 넓게 잡아
    /// 블록 오른쪽에 빈 공간이 남는다.
    @Test func preferredWidthMeasuresTheScaledTitle() {
        let item = WidgetCalendarItem(
            id: "a", title: "긴 제목의 일정 이름", start: at(9), end: at(10),
            kind: .timedEvent, colorHex: nil, isHighPriority: false
        )
        let unscaled = (item.title as NSString)
            .size(withAttributes: [.font: DayTimelineMetrics.titleFont]).width

        #expect(DayTimelineMetrics.preferredWidth(for: item) < unscaled)
    }

    /// 제목이 못 들어가는 폭이면 버린다 — 그 하한도 막대를 포함한다.
    @Test func minimumWidthIncludesTheLeadingColorBar() {
        #expect(DayTimelineMetrics.minimumWidth > DayTimelineMetrics.leadingBarWidth)
    }

    /// 할일은 색 막대 대신 **동그라미**가 앞에 서므로, 예산도 그 폭을 잡아야 한다.
    ///
    /// 동그라미는 폭과 무관하게 언제나 그려진다(일정과 구분되는 유일한 표식이다).
    /// 예산이 이를 모르면 좁은 할일에서 동그라미가 제목을 밀어내 글자가 잘린다.
    @Test func reminderWidthReservesRoomForTheCircleMarker() {
        let title = "빨래"
        let reminderWidth = DayTimelineMetrics.preferredWidth(
            for: WidgetCalendarItem(
                id: "r", title: title, start: at(9), end: at(9),
                kind: .reminder, colorHex: nil, isHighPriority: false
            )
        )
        let measured = (title as NSString)
            .size(withAttributes: [.font: DayTimelineMetrics.titleFont]).width
            * DayTimelineMetrics.titleScale

        #expect(reminderWidth >= measured + DayTimelineMetrics.markerSize)
    }

    /// 최소 폭은 **실제로 그려지는 글자 크기**(= 축소 반영) 기준이어야 한다.
    ///
    /// 블록마다 배율이 달라지지 않으므로 하한도 하나로 정해진다. 말줄임표 몫은 빼야 한다 —
    /// 뷰가 `...`를 만들지 않고 끝에서 잘라내므로, 그만큼 요구하면 한 글자는 들어갈 칸까지
    /// 색 막대로 밀려난다.
    @Test func minimumWidthFitsExactlyOneGlyph() {
        let scaled = DayTimelineMetrics.titleFont.pointSize * DayTimelineMetrics.titleScale

        #expect(DayTimelineMetrics.minimumWidth >= scaled)
        // 두 글자를 요구하지 않는다.
        #expect(DayTimelineMetrics.minimumWidth < scaled * 2)
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
