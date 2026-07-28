//
//  DayTimelineView.swift
//  cueLiveActivity
//
//  1일·3일 위젯의 시간표 — 왼쪽 시간 거터(0~24시) + 날짜 열들.
//  블록 배치는 `DayTimelineLayout`이 계산하고, 이 뷰는 그리기만 한다.
//
//  ⚠️ 레이아웃 원칙
//  - 블록 폭은 **제목 길이**가 정한다(균등분할 아님). 옆 날짜 열을 넘어가도 되고,
//    위젯 오른쪽 끝에서 잘린다 — 레퍼런스와 같은 밀도를 내는 유일한 방법이다.
//  - 클리핑은 **고정 프레임 뒤**에 붙인다. 안쪽 무한 프레임에 붙이면 글자가 칸을 뚫는다.
//

import SwiftUI

struct DayTimelineView: View {
    /// 그릴 날들 — 1일 위젯은 1개, 3일 위젯은 3개.
    let days: [Date]
    /// 날짜(자정) → 그날 항목들.
    let itemsByDay: [Date: [WidgetCalendarItem]]
    var calendar: Calendar = .current

    /// 시간축 눈금 간격(2시간) — 레퍼런스와 동일. 0, 2, … 24가 라벨과 가로선을 함께 만든다.
    private let tickHours = Array(stride(from: 0, through: 24, by: 2))

    var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            let gutter = WidgetCalendarTheme.gutterWidth
            let columnWidth = max(0, geometry.size.width - gutter) / CGFloat(max(1, days.count))

            ZStack(alignment: .topLeading) {
                hourLines(height: height, width: geometry.size.width)
                hourLabels(height: height)
                dayDividers(height: height, columnWidth: columnWidth)
                dayColumns(
                    height: height,
                    columnWidth: columnWidth,
                    totalWidth: geometry.size.width
                )
            }
        }
        // 0시·24시 라벨은 눈금선 위에 세로 중앙 정렬이라 위아래로 반 줄씩 삐져나온다 —
        // 그만큼을 비워 둬야 잘리지 않는다. 아래를 더 크게 잡는 건 위젯의 둥근 모서리 때문:
        // 반 줄(6.5pt)만 두면 "24"가 좌하단 코너에 걸려 잘린다(실기기에서 확인).
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        // 같은 이유로 시간 라벨을 왼쪽 가장자리에서 살짝 띄운다.
        .padding(.leading, Spacing.xs)
    }

    // MARK: - 눈금

    private func hourLines(height: CGFloat, width: CGFloat) -> some View {
        ForEach(tickHours, id: \.self) { hour in
            Rectangle()
                .fill(WidgetCalendarTheme.gridLine)
                // hairline — Divider는 offset과 함께 쓰면 자체 여백이 붙어 눈금이 어긋난다.
                .frame(width: max(0, width - WidgetCalendarTheme.gutterWidth), height: WidgetCalendarTheme.hairline)
                .offset(x: WidgetCalendarTheme.gutterWidth, y: y(for: hour, in: height))
        }
    }

    private func hourLabels(height: CGFloat) -> some View {
        ForEach(tickHours, id: \.self) { hour in
            Text("\(hour)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // 높이 0 상자에 가운데 정렬하면 글자가 위아래로 반씩 흘러넘쳐 **눈금선 위에
                // 세로 중앙 정렬**된다 — 줄높이를 상수로 박지 않고 Dynamic Type을 따라간다.
                .frame(width: WidgetCalendarTheme.gutterWidth - Spacing.xs, height: 0, alignment: .trailing)
                .offset(y: y(for: hour, in: height))
        }
    }

    /// 하루 열 사이 세로 구분선 — 3일 위젯에서만 의미가 있다.
    private func dayDividers(height: CGFloat, columnWidth: CGFloat) -> some View {
        ForEach(1..<max(1, days.count), id: \.self) { index in
            Rectangle()
                .fill(WidgetCalendarTheme.gridLine)
                .frame(width: WidgetCalendarTheme.hairline, height: height)
                .offset(x: WidgetCalendarTheme.gutterWidth + columnWidth * CGFloat(index))
        }
    }

    // MARK: - 블록

    private func dayColumns(height: CGFloat, columnWidth: CGFloat, totalWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let originX = WidgetCalendarTheme.gutterWidth + columnWidth * CGFloat(dayIndex)
            let result = DayTimelineLayout.layout(
                for: itemsByDay[calendar.startOfDay(for: day)] ?? [],
                day: day,
                metrics: DayTimelineLayout.Metrics(
                    availableWidth: availableWidth(
                        dayIndex: dayIndex,
                        originX: originX,
                        columnWidth: columnWidth,
                        totalWidth: totalWidth
                    ),
                    columnWidth: columnWidth,
                    height: height,
                    minimumHeight: DayTimelineMetrics.minimumHeight,
                    minimumWidth: DayTimelineMetrics.minimumWidth,
                    gap: DayTimelineMetrics.gap
                ),
                preferredWidth: DayTimelineMetrics.preferredWidth(for:),
                calendar: calendar
            )

            ForEach(result.blocks) { block in
                DayTimelineBlockView(
                    item: block.item,
                    showsTitle: block.width >= DayTimelineMetrics.barOnlyWidth,
                    showsMarker: block.width >= DayTimelineMetrics.markerWidthThreshold
                )
                // 프레임을 먼저 고정하고 **그 뒤에** 잘라내야 글자가 칸 밖으로 못 나간다.
                .frame(
                    width: block.width,
                    height: max(1, CGFloat(block.endFraction - block.startFraction) * height),
                    alignment: .topLeading
                )
                .clipped()
                .offset(x: originX + block.x, y: CGFloat(block.startFraction) * height)
            }

            // 자리가 없어 못 그린 항목 수 — 그 날짜 열 우상단(대개 새벽이라 비어 있다)에.
            if result.hidden > 0 {
                Text("+\(result.hidden)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: max(0, columnWidth - Spacing.xxs), alignment: .trailing)
                    .offset(x: originX, y: Spacing.xxs)
            }
        }
    }

    /// 그 날짜 열이 가로로 쓸 수 있는 폭.
    ///
    /// 자기 열 + **다음 열의 절반**까지 허용한다. 레퍼런스처럼 긴 제목이 옆 날짜 열로 살짝
    /// 넘어가되, 그 열의 블록 위를 덮어 둘 다 못 읽게 되는 일은 없다. 마지막 열만 위젯
    /// 오른쪽 끝까지 — 넘어갈 이웃이 없으니 남는 공간을 다 쓰는 게 낫다.
    private func availableWidth(
        dayIndex: Int,
        originX: CGFloat,
        columnWidth: CGFloat,
        totalWidth: CGFloat
    ) -> CGFloat {
        let toEdge = max(0, totalWidth - originX)
        guard dayIndex < days.count - 1 else { return toEdge }
        return min(toEdge, columnWidth * 1.5)
    }

    /// 시각 → 세로 위치(pt). 하루를 24등분한 비율에 높이를 곱한다.
    private func y(for hour: Int, in height: CGFloat) -> CGFloat {
        height * CGFloat(hour) / 24
    }
}

/// 시간표 위 블록 하나 — 캘린더 색 배경 + 마커 + 제목.
///
/// 월 셀의 칩과 달리 미리알림에도 배경을 준다 — 시간표에서는 배경이 "이 시간대를 차지한다"는
/// 뜻이라 없으면 어느 시각인지 읽히지 않는다.
private struct DayTimelineBlockView: View {
    let item: WidgetCalendarItem
    /// 제목이 들어갈 폭이 될 때만 true. 아니면 색 막대만 남긴다.
    let showsTitle: Bool
    /// 마커까지 넣을 폭이 될 때만 true. 좁으면 제목에 자리를 양보한다.
    let showsMarker: Bool

    private var color: Color { WidgetCalendarTheme.color(of: item) }

    var body: some View {
        // ZStack이라 배경은 언제나 프레임 전체를 채운다 — 제목이 빠져도 블록이 사라지지 않는다.
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
                .fill(color.opacity(
                    showsTitle
                        ? WidgetCalendarTheme.blockBackgroundOpacity
                        : WidgetCalendarTheme.barOnlyBackgroundOpacity
                ))
            if showsTitle {
                HStack(spacing: DayTimelineMetrics.markerGap) {
                    if showsMarker { marker }
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                        // 명시적 폭을 줘야 `minimumScaleFactor`가 동작한다 — Spacer로 남은
                        // 공간을 밀면 Text가 이상적 크기를 받아 그냥 잘려 나간다.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 좁은 칸에서 두 줄은 글자가 반쪽만 보여 오히려 안 읽힌다 — 한 줄 고정.
                        .lineLimit(1)
                        // 겹침이 깊은 시간대의 블록은 30pt 남짓까지 좁아진다. 그 폭에서
                        // caption2 그대로면 말줄임표만 남아 아무 정보도 없다 — 글자를 줄여
                        // 두세 자라도 보이게 한다(레퍼런스도 그 구간에서 글자가 작아진다).
                        .minimumScaleFactor(DayTimelineMetrics.minimumTitleScale)
                }
                .padding(.horizontal, DayTimelineMetrics.horizontalPadding)
            }
        }
    }

    /// 미리알림은 원, 일정은 사각 — 레퍼런스와 같은 구분.
    @ViewBuilder
    private var marker: some View {
        let size = DayTimelineMetrics.markerSize
        switch item.kind {
        case .reminder where item.isHighPriority:
            Circle().fill(color).frame(width: size, height: size)
        case .reminder:
            Circle().strokeBorder(color, lineWidth: 1).frame(width: size, height: size)
        default:
            RoundedRectangle(cornerRadius: 1).fill(color).frame(width: size, height: size)
        }
    }
}
