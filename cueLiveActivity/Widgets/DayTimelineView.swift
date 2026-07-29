//
//  DayTimelineView.swift
//  cueLiveActivity
//
//  1일·3일 위젯의 시간표 — 왼쪽 시간 거터(0~24시) + 날짜 열들.
//  블록 배치는 `DayTimelineLayout`이 계산하고, 이 뷰는 그리기만 한다.
//
//  ⚠️ 레이아웃 원칙
//  - 블록 폭은 **컬럼 패킹**이 정한다 — 겹치는 것끼리 열 폭을 나누고, 오른쪽이 비면
//    그만큼 흡수한다. 제목 길이는 보지 않는다(→ `DayTimelineLayout`).
//  - 블록은 자기 날짜 열을 넘지 않는다. 날짜 열은 의미 경계다.
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
                dayColumns(height: height, columnWidth: columnWidth)
            }
        }
        // 0시·24시 라벨은 눈금선 위에 세로 중앙 정렬이라 위아래로 반 줄씩 삐져나온다 —
        // 그만큼을 비워 둬야 잘리지 않는다. 아래를 더 크게 잡는 건 위젯의 둥근 모서리 때문:
        // 반 줄(6.5pt)만 두면 "24"가 좌하단 코너에 걸려 잘린다(실기기에서 확인).
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
        // 좌우를 **같은 값으로** — 날짜 머리글과 같은 상수를 써야 거터에 늘어선 숫자들이
        // 세로로 한 줄에 선다.
        .padding(.horizontal, WidgetCalendarTheme.timelineInset)
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
                // 레퍼런스와 나란히 재보니 시간 라벨이 컸다(@3x에서 7.7pt 대 6.3pt).
                // 헤더의 주차 배지와 **같은 상수**를 쓴다 — 같은 거터에 세로로 늘어서는
                // 숫자들이라 크기가 갈리면 한 줄로 안 읽힌다.
                .scaleEffect(WidgetCalendarTheme.hourLabelScale)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                // 높이 0 상자에 가운데 정렬하면 글자가 위아래로 반씩 흘러넘쳐 **눈금선 위에
                // 세로 중앙 정렬**된다 — 줄높이를 상수로 박지 않고 Dynamic Type을 따라간다.
                //
                // 가로는 거터 **중앙**에 놓는다. 오른쪽 정렬이던 시절엔 숫자가 눈금선에 붙고
                // 왼쪽만 넓게 비어 라벨이 격자에 밀려난 것처럼 보였다.
                .frame(width: WidgetCalendarTheme.gutterWidth, height: 0, alignment: .center)
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

    private func dayColumns(height: CGFloat, columnWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
            let originX = WidgetCalendarTheme.gutterWidth + columnWidth * CGFloat(dayIndex)
            let result = DayTimelineLayout.layout(
                for: itemsByDay[calendar.startOfDay(for: day)] ?? [],
                day: day,
                metrics: DayTimelineLayout.Metrics(
                    columnWidth: columnWidth,
                    height: height,
                    minimumHeight: DayTimelineMetrics.minimumHeight,
                    gap: DayTimelineMetrics.gap
                ),
                calendar: calendar
            )

            ForEach(result.blocks) { block in
                let blockHeight = max(1, CGFloat(block.endFraction - block.startFraction) * height)
                DayTimelineBlockView(
                    item: block.item,
                    showsTitle: block.width >= DayTimelineMetrics.barOnlyWidth,
                    height: blockHeight,
                    width: block.width
                )
                // 프레임을 먼저 고정하고 **그 뒤에** 잘라내야 글자가 칸 밖으로 못 나간다.
                .frame(width: block.width, height: blockHeight, alignment: .topLeading)
                .clipped()
                .offset(x: originX + block.x, y: CGFloat(block.startFraction) * height)
            }

            // 못 그린 항목 수(`result.hidden`)는 표시하지 않는다 — 시간표는 "언제 뭐가
            // 있는지"를 보는 화면이라, 시각도 제목도 없는 숫자는 읽는 사람이 할 수 있는 게
            // 없다. 새벽 자리에 뜬 `+2`가 그 시간의 일정으로도 오해된다.
            // (월 위젯의 `+N`은 다르다 — 그건 그 날짜 셀에 묶여 있어 날짜가 곧 맥락이다.)
        }
    }

    /// 그 날짜 열이 가로로 쓸 수 있는 폭.
    ///
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
    /// 블록의 실제 높이(pt) — 제목을 세로 가운데 놓을지 위에 붙일지 가른다.
    let height: CGFloat

    private var color: Color { WidgetCalendarTheme.color(of: item) }

    /// 제목을 세로 가운데 놓을 블록.
    ///
    /// 할일(미리알림)은 **언제나** 해당한다 — 마감 시각 하나뿐이라 길이가 0이고, 늘 최소
    /// 높이로 그려진다. 일정처럼 시간이 늘어날 일이 없으므로 위로 붙일 이유가 없다.
    ///
    /// 일정은 높이로 가린다. 여유를 조금 둔 건 정확히 `minimumHeight`인 것만 잡으면
    /// 31분짜리처럼 몇 pt 더 큰 블록이 위로 붙어, 나란히 놓인 30분 블록과 글자 높이가
    /// 어긋나 보이기 때문이다.
    private var isCompact: Bool {
        if item.kind == .reminder { return true }
        return height < DayTimelineMetrics.minimumHeight + DayTimelineMetrics.minimumHeight / 2
    }

    /// 블록 폭 — 컬럼 패킹이 정한 값(→ `DayTimelineLayout`).
    /// 제목 줄에 이 폭을 걸어야 긴 제목이 `HStack`을 부풀리지 않는다.
    let width: CGFloat

    var body: some View {
        // ZStack이라 배경은 언제나 프레임 전체를 채운다 — 제목이 빠져도 블록이 사라지지 않는다.
        //
        // 정렬은 블록 높이가 정한다. 최소 단위(30분) 블록은 제목 한 줄이 곧 블록 높이라
        // 위로 붙이면 아래쪽만 비어 글자가 칸에서 떠 보인다 — 세로 가운데로 놓는다.
        // 긴 일정은 시작 시각이 곧 정보이므로 제목이 위에 붙어야 한다.
        ZStack(alignment: isCompact ? .leading : .topLeading) {
            RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
                .fill(color.opacity(
                    showsTitle
                        ? WidgetCalendarTheme.blockBackgroundOpacity
                        : WidgetCalendarTheme.barOnlyBackgroundOpacity
                ))
            // 왼쪽 가장자리의 **선명한 색 막대** — 레퍼런스(캘린더 앱)의 핵심 표현이다.
            // 픽셀로 재보니 옅은 배경(RGB 50·57·65) 앞에 원색 막대(144·174·206)가
            // 2pt 폭으로 서 있다. 배경만으로는 캘린더 색이 흐려져 소속이 안 읽힌다.
            //
            // **할일(미리알림)에는 긋지 않는다** — 앞의 동그라미가 이미 같은 자리에서
            // 소속과 종류를 함께 말해주므로, 막대까지 서면 표식이 둘로 겹친다.
            if showsTitle, item.kind != .reminder {
                UnevenRoundedRectangle(
                    topLeadingRadius: WidgetCalendarTheme.chipCornerRadius,
                    bottomLeadingRadius: WidgetCalendarTheme.chipCornerRadius
                )
                .fill(color)
                .frame(width: DayTimelineMetrics.leadingBarWidth)
            }
            if showsTitle {
                HStack(spacing: DayTimelineMetrics.markerGap) {
                    // 할일은 폭과 무관하게 **언제나** 동그라미를 단다 — 일정과 구분되는
                    // 유일한 표식이라(색 막대가 없다) 빠지면 그냥 옅은 색 블록이 된다.
                    // 일정은 반대로 마커가 없다 — 왼쪽 색 막대가 이미 그 자리를 맡는다.
                    if item.kind == .reminder { marker }
                    Text(item.title)
                        .font(.caption2)
                        // 완료된 할일은 한 단계 물러난다 — 지나간 일이라 지금 해야 할 것보다
                        // 눈에 덜 띄어야 한다. 취소선은 좁은 칸에서 글자를 갉아먹어 안 쓴다.
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        // 좁은 칸에서 두 줄은 글자가 반쪽만 보여 오히려 안 읽힌다 — 한 줄 고정.
                        .lineLimit(1)
                        // 말줄임표를 만들지 않는다 — 좁은 블록에서 `...`가 폭의 절반을 먹어
                        // 정작 제목이 한 글자도 안 남는다. 이상적 폭을 그대로 주고 바깥
                        // `.clipped()`가 끝에서 잘라내면 같은 자리에 글자가 더 들어간다.
                        //
                        // 이게 안전한 건 제목 줄(HStack)과 블록(ZStack)이 **둘 다** 배치가 정한
                        // 폭으로 못 박혀 있기 때문이다. 그 고정이 없던 시절엔 긴 제목이
                        // 프레임을 밀어내 옆 날짜 열까지 뚫고 나갔다.
                        .fixedSize(horizontal: true, vertical: false)
                        // caption2가 램프 바닥이라 그 아래는 scaleEffect로만 내려간다.
                        // **폭이 정해진 뒤**에 줄여야 축소분이 잘림에 영향을 주지 않는다.
                        //
                        // 블록마다 배율이 달라지지는 않는다. 겹친 것만 작아지면 한 화면에
                        // 두세 가지 크기가 섞여 시간표가 들쭉날쭉해 보인다.
                        .scaleEffect(DayTimelineMetrics.titleScale, anchor: .leading)
                }
                // 제목 줄 높이를 **축소된 글자 크기**로 고정한다.
                //
                // `scaleEffect`는 레이아웃 크기를 바꾸지 않아, 이 줄은 축소 전 줄높이
                // (caption2 13.1pt)를 그대로 요구한다. 30분 블록은 그보다 낮으므로 줄이
                // 블록 밖으로 위아래 균등하게 넘치고, 바깥 `.clipped()`가 위쪽을 잘라내
                // 글자가 아래로 쏠린 채 남는다(실기기에서 위 5.3pt 대 아래 0pt).
                .frame(height: DayTimelineMetrics.minimumHeight)
                // 왼쪽은 색 막대만큼 더 들인다 — 글자가 막대 위에 얹히지 않게.
                // 막대가 없는 할일은 그 몫을 빼서 동그라미가 가장자리에 바로 붙는다.
                .padding(
                    .leading,
                    item.kind == .reminder
                        ? DayTimelineMetrics.horizontalPadding
                        : DayTimelineMetrics.leadingBarWidth + DayTimelineMetrics.horizontalPadding
                )
                .padding(.trailing, DayTimelineMetrics.horizontalPadding)
                // 제목 줄에 배치가 정한 폭을 건다 — Text가 이 폭을 제안받아 그 안에서
                // 말줄임 처리된다. 안 걸면 긴 제목이 HStack을 부풀린다.
                .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        .clipped()
    }

    /// 미리알림만 원 마커를 단다 — 레퍼런스와 같은 구분.
    ///
    /// 일정은 마커를 그리지 않는다. 왼쪽 색 막대가 이미 소속을 말해주므로, 사각 마커까지
    /// 더하면 같은 정보가 두 번 나오면서 좁은 블록의 제목 자리만 뺏는다.
    @ViewBuilder
    private var marker: some View {
        let size = DayTimelineMetrics.markerSize
        switch item.kind {
        // 완료됐거나 우선순위가 지정된 것은 **채운 원**, 그 외엔 테두리만.
        // 5pt짜리 마커에 체크 같은 기호를 넣으면 형태가 뭉개져 점으로만 보인다.
        case .reminder where item.isCompleted || item.isHighPriority:
            // 지름을 한 단계 줄인다 — 속이 찬 원은 같은 크기여도 커 보인다.
            // 자리는 빈 원과 같게 잡아 제목 시작점이 흔들리지 않는다.
            Circle()
                .fill(color)
                .frame(width: DayTimelineMetrics.filledMarkerSize,
                       height: DayTimelineMetrics.filledMarkerSize)
                .frame(width: size, height: size)
        case .reminder:
            Circle().strokeBorder(color, lineWidth: 1).frame(width: size, height: size)
        default:
            EmptyView()
        }
    }
}
