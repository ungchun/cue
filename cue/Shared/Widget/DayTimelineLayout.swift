//
//  DayTimelineLayout.swift
//  cue / Shared
//

import CoreGraphics
import Foundation

/// 시간표 위 블록 하나 — 세로는 하루를 `0...1`로 본 비율, 가로는 하루 열 시작점 기준 pt.
///
/// 세로만 비율인 이유: 시간축은 위젯 높이에 비례해 늘어나야 하지만, 가로는 **제목 길이**라는
/// pt 단위 사실이 결정한다. 둘을 같은 단위로 억지로 맞추면 어느 한쪽이 깨진다.
struct TimelineBlock: Identifiable, Hashable, Sendable {
    let item: WidgetCalendarItem
    /// 하루 시작(0시)을 0, 자정(24시)을 1로 본 블록 상단 위치.
    let startFraction: Double
    /// 같은 기준의 블록 하단 위치. 최소 높이가 반영돼 항상 `startFraction`보다 크다.
    let endFraction: Double
    /// 그 날짜 열 시작점에서 오른쪽으로 얼마나 떨어졌는지(pt).
    let x: CGFloat
    /// 블록 폭(pt). 옆 날짜 열을 넘어갈 수 있다.
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
/// 3. 폭은 제목이 필요한 만큼. 옆 날짜 열을 넘어가도 되고, 위젯 오른쪽 끝에서 잘린다.
/// 4. 세로로 겹치는 블록은 **이미 놓인 것들의 오른쪽**에 차례로 붙인다.
///
/// 종일 항목은 다루지 않는다 — 시간축에 위치가 없어 뷰가 별도 스트립에 그린다.
enum DayTimelineLayout {

    /// 배치에 필요한 실제 치수 — 뷰가 `GeometryReader`로 잰 값을 넘긴다.
    struct Metrics: Sendable {
        /// 이 날짜 열 시작점부터 그릴 수 있는 최대 폭 — 옆 날짜 열로의 **넘침 허용** 한계.
        let availableWidth: CGFloat
        /// 하루 열 자체의 폭. 겹치는 블록끼리 나눠 갖는 예산은 이 값이다.
        let columnWidth: CGFloat
        /// 시간표 전체 높이(pt).
        let height: CGFloat
        /// 블록 최소 높이(pt).
        let minimumHeight: CGFloat
        /// 이보다 좁으면 그리지 않는다.
        let minimumWidth: CGFloat
        /// 인접 블록 사이 가로 틈.
        let gap: CGFloat
    }

    /// 하루 길이. 서머타임으로 23/25시간인 날이 있지만, 시간축 눈금(0~24)이 고정이라
    /// 비율 환산도 24시간 고정으로 맞춘다 — 눈금과 블록이 어긋나지 않는 쪽을 택했다.
    private static let dayLength: TimeInterval = 24 * 60 * 60

    /// `day`가 속한 하루에 대한 블록 배치. 입력 순서와 무관하게 결과는 항상 같다.
    ///
    /// `preferredWidth`를 주입받는 이유는 텍스트 측정(UIKit)에서 배치 규칙을 떼어내
    /// 결정론적으로 테스트하기 위해서다.
    static func layout(
        for items: [WidgetCalendarItem],
        day: Date,
        metrics: Metrics,
        preferredWidth: (WidgetCalendarItem) -> CGFloat,
        calendar: Calendar = .current
    ) -> DayTimelineLayoutResult {
        let dayStart = calendar.startOfDay(for: day)
        let dayEnd = dayStart.addingTimeInterval(dayLength)

        let spans = items
            .filter { !$0.isAllDay }
            .compactMap { span(for: $0, dayStart: dayStart, dayEnd: dayEnd, metrics: metrics) }

        // 폭 상한은 **겹침 구조**에서, 배치 순서는 **종류·시각**에서 나온다 — 서로 다른
        // 정렬이 필요하므로 두 단계로 나눈다.
        let limits = widthLimits(spans, metrics: metrics)

        return place(
            spans.sorted(by: precedes),
            metrics: metrics,
            budgets: limits,
            preferredWidth: preferredWidth
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

    /// 배치 순서 — **캘린더 일정 먼저, 미리알림 나중**. 그다음 위에서부터, 같은 높이면 긴 쪽,
    /// 그래도 같으면 id로 확정한다.
    ///
    /// 일정을 먼저 놓는 게 핵심이다. 시각 순으로만 놓으면 오전에 몰린 짧은 미리알림들이
    /// 왼쪽을 다 차지해, 하루를 관통하는 "출근" 같은 긴 일정이 오른쪽 끝까지 밀리거나 아예
    /// 잘려 나간다. 레퍼런스에서 일정 블록이 언제나 열 맨 왼쪽에 기둥처럼 서 있는 이유다.
    private static func precedes(_ lhs: Span, _ rhs: Span) -> Bool {
        let lhsIsReminder = lhs.item.kind == .reminder
        let rhsIsReminder = rhs.item.kind == .reminder
        if lhsIsReminder != rhsIsReminder { return !lhsIsReminder }
        if lhs.top != rhs.top { return lhs.top < rhs.top }
        if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
        return lhs.item.id < rhs.item.id
    }

    // MARK: - 폭 상한

    /// 블록 하나에 허용된 가로 예산 — 폭 상한과, 넘어설 수 없는 오른쪽 경계.
    private struct Budget {
        let width: CGFloat
        let boundary: CGFloat
    }

    /// 세로로 겹치는 것끼리 묶고, 그 묶음의 **최대 동시 겹침 수**로 폭 상한을 나눈다.
    ///
    /// 제목 길이만으로 폭을 정하면 오전처럼 여섯 겹으로 겹치는 시간대가 가로 공간을 통째로
    /// 먹어 뒤 블록이 전부 버려진다. 반대로 항상 균등분할하면 겹침 없는 시간대의 블록까지
    /// 좁아진다. **겹치는 묶음 안에서만** 나누면 둘 다 피할 수 있다 — 레퍼런스도 겹칠 때만
    /// 제목이 짧게 잘려 있다.
    private static func widthLimits(_ spans: [Span], metrics: Metrics) -> [String: Budget] {
        var limits: [String: Budget] = [:]
        let ordered = spans.sorted { $0.top == $1.top ? $0.bottom < $1.bottom : $0.top < $1.top }

        var cluster: [Span] = []
        var clusterBottom = -CGFloat.greatestFiniteMagnitude

        func close() {
            guard !cluster.isEmpty else { return }
            let concurrency = max(1, maximumConcurrency(cluster))
            // 겹치는 게 없는 블록만 제목 길이만큼 옆 날짜 열로 넘어갈 수 있다. 겹치는
            // 블록끼리는 **자기 열 폭 안에서** 나눠 가진다 — 안 그러면 27일 블록이 28일 열을
            // 덮어 둘 다 못 읽게 된다(레퍼런스도 단독 블록만 옆 열로 넘어간다).
            let budget = concurrency == 1
                // 그 시간대에 자기 혼자다 → 제목 길이만큼, 옆 날짜 열까지 넘어가도 좋다.
                ? Budget(width: metrics.availableWidth, boundary: metrics.availableWidth)
                // 겹친다 → 폭도 위치도 **자기 열 안에** 가둔다. 상한만 걸고 경계를 안 막으면
                // 오른쪽으로 밀리다가 결국 옆 날짜 열의 블록 위를 덮는다.
                : Budget(
                    // 블록 사이 틈도 예산에서 뺀다 — 안 빼면 k개가 폭을 정확히 채운 뒤
                    // 틈 때문에 마지막 하나가 경계 밖으로 밀려 통째로 버려진다.
                    width: (metrics.columnWidth - metrics.gap * CGFloat(concurrency - 1))
                        / CGFloat(concurrency),
                    boundary: metrics.columnWidth
                )
            for span in cluster { limits[span.item.id] = budget }
            cluster.removeAll()
        }

        for span in ordered {
            if span.top >= clusterBottom { close(); clusterBottom = span.bottom }
            cluster.append(span)
            clusterBottom = max(clusterBottom, span.bottom)
        }
        close()

        return limits
    }

    /// 묶음 안에서 한 순간에 최대 몇 개가 동시에 겹치는지 — 시작/끝을 훑는 스윕으로 센다.
    /// "묶음 크기"로 세면 안 된다. 여덟 개가 사슬처럼 이어져도 동시에 겹치는 건 둘뿐일 수 있다.
    private static func maximumConcurrency(_ cluster: [Span]) -> Int {
        struct Edge {
            let y: CGFloat
            /// 시작은 +1, 끝은 -1.
            let delta: Int
        }

        var edges: [Edge] = []
        edges.reserveCapacity(cluster.count * 2)
        for span in cluster {
            edges.append(Edge(y: span.top, delta: 1))
            edges.append(Edge(y: span.bottom, delta: -1))
        }
        // 끝(-1)을 시작(+1)보다 먼저 처리해야 경계만 맞닿은 블록을 겹침으로 세지 않는다.
        edges.sort { $0.y == $1.y ? $0.delta < $1.delta : $0.y < $1.y }

        var current = 0
        var maximum = 0
        for edge in edges {
            current += edge.delta
            maximum = max(maximum, current)
        }
        return maximum
    }

    // MARK: - 가로 배치

    /// **가장 왼쪽 빈 자리**에 넣는다(first fit).
    ///
    /// 단순히 "겹치는 것들의 오른쪽 끝"에 붙이면 안 된다. 8시 블록과 10시 블록은 서로 겹치지
    /// 않는데도 9시 블록을 통해 사슬처럼 이어져, x가 왼쪽으로 되돌아오지 못하고 계속 누적된다.
    /// 그러면 오전에 일정이 몰린 날은 뒤쪽 항목이 오른쪽 끝을 넘겨 통째로 버려진다.
    /// 후보 자리(0과 이미 놓인 블록들의 오른쪽 끝)를 왼쪽부터 훑어 **실제로 비어 있는** 첫
    /// 자리에 넣으면, 레퍼런스처럼 뒤 블록이 앞서 비워진 왼쪽 자리를 다시 쓴다.
    private static func place(
        _ spans: [Span],
        metrics: Metrics,
        budgets: [String: Budget],
        preferredWidth: (WidgetCalendarItem) -> CGFloat
    ) -> DayTimelineLayoutResult {
        /// 이미 놓인 블록이 차지한 세로 구간과 가로 구간. `right`에는 인접 틈이 포함돼 있어
        /// 가로 충돌 판정만으로 블록 사이 간격이 자연히 확보된다.
        struct Placed {
            let top: CGFloat
            let bottom: CGFloat
            let left: CGFloat
            let right: CGFloat
        }

        var blocks: [TimelineBlock] = []
        var hidden = 0
        var placed: [Placed] = []

        for span in spans {
            let budget = budgets[span.item.id]
                ?? Budget(width: metrics.availableWidth, boundary: metrics.availableWidth)
            // 예산이 최소 폭보다 작아질 수 있다(겹침이 아주 깊은 시간대) — 그때는 최소 폭을
            // 지키고, 대신 자리를 못 찾은 항목이 `+N`으로 넘어간다.
            let cap = max(budget.width, metrics.minimumWidth)

            var candidates = [CGFloat.zero]
            candidates.append(contentsOf: placed.map(\.right))
            candidates = Array(Set(candidates)).sorted()

            var slot: (x: CGFloat, width: CGFloat)?
            for x in candidates {
                let width = min(preferredWidth(span.item), cap, budget.boundary - x)
                guard width >= metrics.minimumWidth else { continue }
                let collides = placed.contains { other in
                    overlaps(span, other.top, other.bottom)
                        && x < other.right && other.left < x + width
                }
                if !collides {
                    slot = (x, width)
                    break
                }
            }

            guard let slot else {
                // 어느 자리에도 최소 폭이 안 나온다 → 알아볼 수 없는 조각 대신 개수만 알린다.
                hidden += 1
                continue
            }

            blocks.append(
                TimelineBlock(
                    item: span.item,
                    startFraction: fraction(span.top, in: metrics.height),
                    endFraction: fraction(span.bottom, in: metrics.height),
                    x: slot.x,
                    width: slot.width
                )
            )
            placed.append(
                Placed(
                    top: span.top, bottom: span.bottom,
                    left: slot.x, right: slot.x + slot.width + metrics.gap
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
