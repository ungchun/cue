//
//  DayTimelineLayout.swift
//  cue / Shared
//

import CoreGraphics
import Foundation

/// 시간표 위 블록 하나 — 세로는 하루를 `0...1`로 본 비율, 가로는 하루 열 시작점 기준 pt.
///
/// 세로만 비율인 이유: 시간축은 위젯 높이에 비례해 늘어나야 하지만, 가로는 열 폭을 컬럼 수로
/// 나눈 pt 값이다. 둘을 같은 단위로 억지로 맞추면 어느 한쪽이 깨진다.
struct TimelineBlock: Identifiable, Hashable, Sendable {
    let item: WidgetCalendarItem
    /// 하루 시작(0시)을 0, 자정(24시)을 1로 본 블록 상단 위치.
    let startFraction: Double
    /// 같은 기준의 블록 하단 위치. 최소 높이가 반영돼 항상 `startFraction`보다 크다.
    let endFraction: Double
    /// 그 날짜 열 시작점에서 오른쪽으로 얼마나 떨어졌는지(pt).
    let x: CGFloat
    /// 블록 폭(pt). 자기 날짜 열 안에 머문다.
    let width: CGFloat

    var id: String { item.id }
}

/// 하루치 배치 결과 — 그릴 블록들과, 자리가 없어 못 그린 개수.
struct DayTimelineLayoutResult: Sendable {
    let blocks: [TimelineBlock]
    /// 가로 공간이 모자라 버려진 항목 수 — 뷰가 그 날짜 열 위에 `+N`으로 알린다.
    let hidden: Int

    static let empty = DayTimelineLayoutResult(blocks: [], hidden: 0)
}

/// 1일·3일 위젯 시간표의 배치 계산.
///
/// 규칙은 넷:
/// 1. 하루 밖으로 삐져나간 일정은 그날 경계로 자른다.
/// 2. 모든 블록은 제목 한 줄이 들어갈 **최소 높이**를 갖는다(미리알림은 길이가 0이다).
/// 3. 폭은 **컬럼 패킹**이 정한다 — 겹치는 것끼리 열 폭을 나누고, 오른쪽이 비면 흡수한다.
///    제목 길이는 보지 않는다.
/// 4. 블록은 자기 날짜 열을 넘지 않는다.
///
/// 종일 항목은 다루지 않는다 — 시간축에 위치가 없어 뷰가 별도 스트립에 그린다.
enum DayTimelineLayout {

    /// 배치에 필요한 실제 치수 — 뷰가 `GeometryReader`로 잰 값을 넘긴다.
    struct Metrics: Sendable {
        /// 하루 열의 폭. 겹치는 블록끼리 이 폭을 나눠 갖는다.
        ///
        /// 블록은 **이 열을 넘지 않는다.** 조사해 보니 FullCalendar·react-big-calendar 등
        /// 어떤 캘린더 구현도 날짜 열을 넘기지 않는다 — 날짜 열은 의미 경계라, 넘어가면
        /// 어느 날 일정인지 모호해진다.
        let columnWidth: CGFloat
        /// 시간표 전체 높이(pt).
        let height: CGFloat
        /// 블록 최소 높이(pt).
        let minimumHeight: CGFloat
        /// 인접 블록 사이 가로 틈.
        let gap: CGFloat
    }

    /// 하루 길이. 서머타임으로 23/25시간인 날이 있지만, 시간축 눈금(0~24)이 고정이라
    /// 비율 환산도 24시간 고정으로 맞춘다 — 눈금과 블록이 어긋나지 않는 쪽을 택했다.
    private static let dayLength: TimeInterval = 24 * 60 * 60

    /// 자리가 모자랄 때 허용하는 **최후의 폭**. 제목은 못 넣어도 "여기 뭔가 있다"는
    /// 색 막대는 선다. 레퍼런스(캘린더 앱)도 겹침이 깊은 구간에서 이 정도까지 그린다
    /// (실기기 스크린샷에서 2.3pt짜리 막대를 쟀다).
    private static let slimmestWidth: CGFloat = 2

    /// `day`가 속한 하루에 대한 블록 배치. 입력 순서와 무관하게 결과는 항상 같다.
    ///
    /// 폭은 **컬럼 패킹**이 정한다 — 제목 길이는 보지 않는다. 겹치는 것끼리 폭을 나누고,
    /// 오른쪽이 비어 있으면 그만큼 흡수한다(→ `packColumns`).
    static func layout(
        for items: [WidgetCalendarItem],
        day: Date,
        metrics: Metrics,
        calendar: Calendar = .current
    ) -> DayTimelineLayoutResult {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = dayStart.addingTimeInterval(dayLength)

        let spans = items
            .filter { !$0.isAllDay }
            .compactMap { span(for: $0, dayStart: dayStart, dayEnd: dayEnd, metrics: metrics) }

        // 컬럼 배정은 **겹침 구조**에서, 그리는 순서는 **종류·시각**에서 나온다 —
        // 서로 다른 정렬이 필요하므로 두 단계로 나눈다.
        let packed = packColumns(spans)

        return place(
            spans.sorted(by: precedes),
            metrics: metrics,
            slots: packed.slots,
            columnCounts: packed.columns
        )
    }

    // MARK: - 세로 구간

    /// 하루 경계로 자르고 최소 높이를 보장한 표시 구간(pt 기준 상·하단).
    private struct Span {
        let item: WidgetCalendarItem
        /// 시간축 위 상단 위치(pt).
        let top: CGFloat
        /// 시간축 위 하단 위치(pt) — 최소 높이가 반영된 **렌더 높이** 기준.
        let bottom: CGFloat
        /// 겹침 정렬 안정화를 위한 원래 시각.
        let start: Date
        /// 같은 시각일 때 긴 쪽을 먼저 놓기 위한 원래 길이.
        let duration: TimeInterval
    }

    private static func span(
        for item: WidgetCalendarItem,
        dayStart: Date,
        dayEnd: Date,
        metrics: Metrics
    ) -> Span? {
        // 길이 0(미리알림)은 시작 시각이 하루 안에 있기만 하면 표시한다 — 구간 겹침만 보면
        // 자정 정각 항목이 사라진다.
        let rawEnd = max(item.start, item.end)
        guard item.start < dayEnd, rawEnd >= dayStart else { return nil }

        let start = max(item.start, dayStart)
        let end = min(rawEnd, dayEnd)

        var top = CGFloat(start.timeIntervalSince(dayStart) / dayLength) * metrics.height
        var bottom = CGFloat(end.timeIntervalSince(dayStart) / dayLength) * metrics.height

        // 최소 높이 보장은 **pt로** 한다. 시간으로 하면 위젯 높이가 달라질 때마다 겹침
        // 판정이 달라져, 화면에서 겹쳐 보이는 두 블록이 같은 자리에 포개지는 사고가 난다.
        if bottom - top < metrics.minimumHeight {
            bottom = top + metrics.minimumHeight
            // 자정 직전이라 아래로 못 늘리면 위로 민다 — 하단을 넘겨 잘리는 것보다 낫다.
            if bottom > metrics.height {
                bottom = metrics.height
                top = max(0, bottom - metrics.minimumHeight)
            }
        }

        return Span(
            item: item, top: top, bottom: bottom,
            start: start, duration: end.timeIntervalSince(start)
        )
    }

    /// **그리는 순서** — 캘린더 일정 먼저, 미리알림 나중. 일정끼리는 긴 것 먼저,
    /// 같은 길이면 위에서부터, 그래도 같으면 id로 확정한다.
    ///
    /// 가로 위치는 여기서 정해지지 않는다 — 그건 `packColumns`의 몫이다. 이 정렬이 하는 일은
    /// **결과 배열의 순서를 고정**하는 것뿐이다. 순서가 렌더마다 뒤집히면 SwiftUI가 같은
    /// 화면을 다시 그리며 위젯이 이유 없이 깜빡인다.
    private static func precedes(_ lhs: Span, _ rhs: Span) -> Bool {
        let lhsIsReminder = lhs.item.kind == .reminder
        let rhsIsReminder = rhs.item.kind == .reminder
        if lhsIsReminder != rhsIsReminder { return !lhsIsReminder }
        if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
        if lhs.top != rhs.top { return lhs.top < rhs.top }
        return lhs.item.id < rhs.item.id
    }

    // MARK: - 컬럼 패킹
    //
    // 캘린더 앱들이 공통으로 쓰는 표준 알고리즘이다(FullCalendar·react-big-calendar 등).
    // 규칙은 두 줄로 끝난다:
    //
    //   1. 시간이 겹치는 것끼리는 **폭이 같다**
    //   2. 그 조건 아래 **최대한 넓게**
    //
    // 폭은 제목 길이가 아니라 **컬럼 인덱스와 개수**로만 정해진다. 예전엔 제목 길이로
    // 정했는데, 그러면 긴 제목이 옆 날짜를 침범하고 "상한 몇 pt?"가 계속 임의값이 됐다.

    /// 컬럼 패킹 결과 — 몇 번째 칸에, 몇 칸을 차지하는지.
    private struct Slot {
        let column: Int
        /// 오른쪽으로 흡수한 빈 칸까지 포함한 칸 수.
        let span: Int
    }

    /// 겹치는 것끼리 묶어 컬럼을 배정하고, 오른쪽 빈 칸을 흡수시킨다.
    ///
    /// 3단계다:
    /// 1. **충돌 그룹** — 시각 순으로 훑다가 `top >= 그룹의 최하단`이면 그룹을 닫는다.
    ///    그룹끼리는 완전히 독립이라, 오전의 혼잡이 오후 블록의 폭에 영향을 주지 않는다.
    /// 2. **그리디 컬럼 배정** — 왼쪽부터 훑어 "그 컬럼의 것들과 안 겹치는" 첫 칸에 넣는다.
    ///    결과 컬럼 수가 곧 그 그룹의 최대 동시 겹침이다.
    /// 3. **확장** — 오른쪽 칸들이 자기 시간대에 비어 있으면 흡수한다. 첫 막힌 칸에서 멈춘다.
    ///
    /// 확장이 없으면 3일 위젯처럼 열이 좁을 때(104pt) 3컬럼 그룹의 단독 블록이 35pt로
    /// 렌더돼 글자가 안 읽힌다.
    private static func packColumns(_ spans: [Span]) -> (slots: [String: Slot], columns: [String: Int]) {
        var slots: [String: Slot] = [:]
        var columnCounts: [String: Int] = [:]

        // 그룹 나누기는 시각 순으로 — 배치 순서(`precedes`)와는 다른 정렬이 필요하다.
        //
        // 마지막 `id` 비교가 **결정론을 만든다**. 구간이 완전히 같으면(`top`·`bottom` 동일)
        // 앞의 두 조건이 양방향 모두 false여서 순서가 입력에 맡겨지고, `sort`는 안정 정렬을
        // 보장하지 않는다. 그 순서가 아래 그리디 컬럼 배정에 그대로 흘러 **가로 위치가**
        // EventKit 조회 순서마다 뒤집혔다 — 같은 시각 두 일정의 좌우가 갱신마다 바뀌어 보였다.
        // 그리는 순서(`precedes`)는 이미 `id`로 확정돼 있어 세로만 안정적이었다.
        let ordered = spans.sorted {
            if $0.top != $1.top { return $0.top < $1.top }
            if $0.bottom != $1.bottom { return $0.bottom > $1.bottom }
            return $0.item.id < $1.item.id
        }

        var cluster: [Span] = []
        var clusterBottom = -CGFloat.greatestFiniteMagnitude

        func close() {
            guard !cluster.isEmpty else { return }
            defer { cluster.removeAll() }

            // 2단계 — 그리디 컬럼 배정.
            var columns: [[Span]] = []
            var columnOf: [String: Int] = [:]
            for span in cluster {
                var placed = false
                for (index, column) in columns.enumerated() {
                    // 그 컬럼의 어느 것과도 안 겹치면 여기 들어간다.
                    if !column.contains(where: { overlaps($0, span.top, span.bottom) }) {
                        columns[index].append(span)
                        columnOf[span.item.id] = index
                        placed = true
                        break
                    }
                }
                if !placed {
                    columnOf[span.item.id] = columns.count
                    columns.append([span])
                }
            }

            // 3단계 — 오른쪽 빈 칸 흡수. **첫 막힌 칸에서 멈춘다**(건너뛰지 않는다).
            let total = max(1, columns.count)
            for span in cluster {
                let index = columnOf[span.item.id] ?? 0
                var reach = 1
                var next = index + 1
                while next < columns.count {
                    if columns[next].contains(where: { overlaps($0, span.top, span.bottom) }) { break }
                    reach += 1
                    next += 1
                }
                slots[span.item.id] = Slot(column: index, span: reach)
                columnCounts[span.item.id] = total
            }
        }

        for span in ordered {
            if span.top >= clusterBottom { close(); clusterBottom = span.bottom }
            cluster.append(span)
            clusterBottom = max(clusterBottom, span.bottom)
        }
        close()

        return (slots, columnCounts)
    }

    // MARK: - 가로 배치

    /// 컬럼 배정 결과를 실제 pt 좌표로 옮긴다.
    ///
    /// 폭은 `열 폭 / 컬럼 수 × 차지한 칸 수`. 여기서 정해지는 값이라 제목 길이는 보지 않는다.
    /// 블록 사이 틈(`gap`)은 각 블록의 오른쪽에서 뗀다 — 칸 경계 자체는 그대로 두고 그려지는
    /// 폭만 줄이므로, 마지막 칸이 열 밖으로 밀려나는 일이 없다.
    private static func place(
        _ spans: [Span],
        metrics: Metrics,
        slots: [String: Slot],
        columnCounts: [String: Int]
    ) -> DayTimelineLayoutResult {
        var blocks: [TimelineBlock] = []
        var hidden = 0

        for span in spans {
            let slot = slots[span.item.id] ?? Slot(column: 0, span: 1)
            let total = max(1, columnCounts[span.item.id] ?? 1)
            let unit = metrics.columnWidth / CGFloat(total)

            let x = unit * CGFloat(slot.column)
            // 틈은 오른쪽에서만 뗀다. 마지막 칸까지 쓰는 블록은 열 끝에 딱 맞아야 하므로
            // 그때는 떼지 않는다.
            let reachesEnd = slot.column + slot.span >= total
            let width = unit * CGFloat(slot.span) - (reachesEnd ? 0 : metrics.gap)

            // 색 막대 한 줄 그을 폭조차 안 나오면 아무 정보도 못 준다.
            guard width >= slimmestWidth else {
                hidden += 1
                continue
            }

            blocks.append(
                TimelineBlock(
                    item: span.item,
                    startFraction: fraction(span.top, in: metrics.height),
                    endFraction: fraction(span.bottom, in: metrics.height),
                    x: x,
                    width: width
                )
            )
        }

        return DayTimelineLayoutResult(blocks: blocks, hidden: hidden)
    }

    /// 세로 겹침 — 경계만 맞닿는 건 겹침이 아니다.
    private static func overlaps(_ span: Span, _ top: CGFloat, _ bottom: CGFloat) -> Bool {
        span.top < bottom && top < span.bottom
    }

    private static func fraction(_ value: CGFloat, in height: CGFloat) -> Double {
        guard height > 0 else { return 0 }
        return min(1, max(0, Double(value / height)))
    }
}
