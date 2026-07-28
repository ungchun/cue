//
//  WidgetItemChip.swift
//  cueLiveActivity
//
//  월 캘린더 위젯 날짜 셀 안의 항목 한 줄.
//
//  세 종류를 눈으로 구분되게 그린다:
//  - 종일 일정  : 캘린더 색으로 **꽉 채운** 칩 (제목만)
//  - 시간 일정  : 캘린더 색을 **옅게** 깐 배경 + 제목 앞 작은 사각
//  - 미리알림   : 배경 없이 제목 앞 원형 마커 (우선순위 지정이면 채운 원)
//

import SwiftUI

struct WidgetItemChip: View {
    let item: WidgetCalendarItem
    /// 칩 높이 — 월 그리드가 행 높이에서 역산해 넘긴다. 셀에 정해진 개수가 반드시
    /// 들어가야 하므로 뷰가 스스로 정하지 않는다.
    var height: CGFloat = MonthWidgetMetrics.chipLine.rounded(.up)
    /// 여러 날을 가로지르는 막대인지. 켜지면 시간 일정도 종일과 **같은 꽉 찬 배경**으로
    /// 그린다 — 옅은 배경은 하루짜리 칩을 구분하려는 장치라, 며칠을 잇는 막대에서는
    /// 존재감만 흐려진다.
    var isSpanning: Bool = false

    private var color: Color { WidgetCalendarTheme.color(of: item) }

    var body: some View {
        content
            // 높이를 **고정**한다 — 셀에 들어갈 개수가 먼저 정해지고 높이가 거기 맞춰지므로,
            // 뷰가 자연 크기로 커지면 칩이 셀을 넘쳐 그리드 전체가 밀려난다.
            .frame(height: height)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        // 종일은 하루짜리든 연속이든 가운데 정렬 — 마커가 없어 왼쪽에 기준점이 없으니
        // 색으로 꽉 찬 칩 안에서는 글자가 가운데 있어야 안정돼 보인다.
        case .allDayEvent:
            filled(showsMarker: false, centersTitle: true)
        // 며칠에 걸친 시간 일정도 종일과 똑같은 배경으로 — 다만 시간 일정임을 알리는 세로
        // 막대는 남긴다. 하루짜리 시간 일정만 옅은 배경으로 남는다.
        // 연속 시간 일정은 앞에 세로 막대가 있어 왼쪽에 기준점이 생긴다 — 다른 시간 일정
        // 칩과 글자 시작점을 맞춘다.
        case .timedEvent where isSpanning:
            filled(showsMarker: true, centersTitle: false)
        case .timedEvent:
            marked { barMarker(fill: color) }
                .background(shape.fill(color.opacity(WidgetCalendarTheme.softBackgroundOpacity)))
        case .reminder:
            // 미리알림은 배경 없이 — 셀 안에서 일정과 한눈에 갈린다(레퍼런스와 동일).
            marked { circleMarker }
        }
    }

    /// 캘린더 색으로 꽉 채운 칩 — 종일 일정과 연속 일정 막대가 공유한다.
    ///
    /// 마커도 글자와 **같은 대비색**으로 그린다. 배경이 이미 캘린더 색으로 꽉 차 있어서
    /// 마커까지 같은 색이면 배경에 묻혀 아예 안 보인다.
    private func filled(showsMarker: Bool, centersTitle: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            if showsMarker {
                barMarker(fill: WidgetCalendarTheme.filledChipForeground(of: item))
            }
            title
                .foregroundStyle(WidgetCalendarTheme.filledChipForeground(of: item))
                // 왼쪽 정렬일 때는 시간 일정 칩과 글자 시작점이 맞는다 — 배경색만 종일
                // 스타일이고 읽는 흐름은 다른 칩과 같아야 격자가 한 덩어리로 읽힌다.
                .frame(maxWidth: .infinity, alignment: centersTitle ? .center : .leading)
        }
        // 시간 일정 칩(`marked`)과 같은 여백 — 왼쪽 시작점이 어긋나면 정렬을 맞춘 의미가 없다.
        .padding(.horizontal, Spacing.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(color))
    }

    private var title: some View {
        Text(item.title)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            // 칩 높이는 셀에 들어갈 개수에 맞춰 눌리므로(5주 달이면 약 11.7pt) 11pt 글자의
            // 줄높이(13.1pt)보다 얇아진다. 그때 글자가 셀을 뚫는 대신 따라 줄어들게 한다.
            //
            // 그래서 **보이는 크기는 선언값 11pt가 아니라 행 높이가 정한다** — 5주 달이면
            // 11.7/13.1 ≈ 0.89배로 눌려 약 9.8pt, 행이 넉넉한 4주 달이면 11pt 그대로다.
            // 0.8은 그 자연 축소값보다 낮은 안전망일 뿐이라 평소엔 걸리지 않는다.
            .minimumScaleFactor(0.8)
    }

    /// 마커 + 제목 한 줄 — 시간 일정과 미리알림이 공유하는 뼈대.
    private func marked<Marker: View>(@ViewBuilder _ marker: () -> Marker) -> some View {
        // 마커가 얇은 세로 막대라 간격이 좁으면 제목의 첫 글자에 붙어 획처럼 읽힌다.
        HStack(spacing: Spacing.xs) {
            marker()
            title
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 시간 일정 마커 — **세로로 긴 막대**. 정사각형은 좁은 셀에서 가로 폭만 잡아먹으면서
    /// 제목 자리를 빼앗는데, 세로 막대는 폭을 절반만 쓰고도 칩 높이 전체를 채워 더 잘 보인다
    /// (LA 일정 행의 좌측 색 막대와 같은 표현).
    private func barMarker(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: WidgetCalendarTheme.markerBarWidth / 2)
            .fill(fill)
            .frame(width: WidgetCalendarTheme.markerBarWidth)
            .frame(maxHeight: .infinity)
            // 줄박스에는 글자 위아래 투명 여백이 포함돼 있어, 막대를 칩 높이에 꽉 채우면
            // 글자보다 길어 보인다 — 위아래를 인셋해 보이는 글자 높이에 맞춘다.
            .padding(.vertical, WidgetCalendarTheme.markerBarInset)
    }

    @ViewBuilder
    private var circleMarker: some View {
        if item.isHighPriority {
            Circle()
                .fill(color)
                .frame(width: WidgetCalendarTheme.markerSize, height: WidgetCalendarTheme.markerSize)
        } else {
            Circle()
                .strokeBorder(color, lineWidth: 1)
                .frame(width: WidgetCalendarTheme.markerSize, height: WidgetCalendarTheme.markerSize)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
    }
}
