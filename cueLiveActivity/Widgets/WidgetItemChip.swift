//
//  WidgetItemChip.swift
//  cueLiveActivity
//
//  월 캘린더 위젯 날짜 셀 안의 항목 한 줄.
//
//  세 종류를 눈으로 구분되게 그린다:
//  - 종일 일정  : 캘린더 색으로 **꽉 채운** 칩 (제목만)
//  - 시간 일정  : 캘린더 색을 **옅게** 깐 배경 + 제목 앞 작은 사각
//  - 미리알림   : 배경 없이 제목 앞 원형 마커 (완료·우선순위 지정이면 채운 원)
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
            titleRow(centered: centersTitle)
                .foregroundStyle(WidgetCalendarTheme.filledChipForeground(of: item))
        }
        // 시간 일정 칩(`marked`)과 같은 여백 — 왼쪽 시작점이 어긋나면 정렬을 맞춘 의미가 없다.
        .padding(.horizontal, Spacing.xxs)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(shape.fill(color))
    }

    /// 제목 한 줄을 칩 폭 안에 앉힌다 — 넘치면 **말줄임표 없이 끝을 자른다**.
    ///
    /// 칩 폭이 좁아(3일 위젯 종일 칩은 50pt) `...`가 폭의 상당 부분을 먹으면 정작 제목은
    /// 한두 글자만 남는다. 이상적 폭을 그대로 주고 칩 바깥 `.clipped()`가 끝에서 잘라내면
    /// 같은 자리에 글자가 더 들어간다(시간표 블록과 같은 규칙 → `DayTimelineView`).
    ///
    /// 가운데 정렬은 **들어갈 때만** 유지된다. Spacer 둘로 가운데를 잡으면, 제목이 넘칠 땐
    /// Spacer가 0으로 눌리며 글자가 왼쪽 끝에서 시작해 뒤쪽만 잘린다. `alignment: .center`
    /// 프레임으로는 넘칠 때 앞뒤가 같이 잘려 제목 첫 글자부터 사라진다.
    ///
    /// 폭을 만드는 뷰(`Color.clear`)와 글자를 **분리**한다 — 글자는 overlay로 얹는다.
    /// `.frame(maxWidth: .infinity)`만으로는 못 막는다: 그 프레임은 자식이 제안보다 크면
    /// **자식 크기까지 같이 늘어나서**, 클립 기준 프레임 자체가 커져 칩이 옆 날짜 열을
    /// 뚫고 나갔다(실기기에서 확인). overlay는 부모 크기에 영향을 주지 않으므로,
    /// 이 줄의 폭은 언제나 칩이 받은 몫 그대로이고 넘치는 글자만 여기서 잘린다.
    private func titleRow(centered: Bool) -> some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 넘칠 때는 **왼쪽 끝에서 시작**해 뒤만 잘려야 한다. 가운데 정렬은 안쪽
            // Spacer가 맡아서, 들어갈 때만 가운데로 서고 넘치면 0으로 눌린다.
            .overlay(alignment: .leading) {
                HStack(spacing: Spacing.zero) {
                    if centered { Spacer(minLength: Spacing.zero) }
                    title
                    Spacer(minLength: Spacing.zero)
                }
            }
            .clipped()
    }

    private var title: some View {
        Text(item.title)
            .font(.caption)
            .lineLimit(1)
            // 폭이 모자랄 때의 안전망으로만 남긴다. 아래 `fixedSize`가 폭 제안을 없애므로
            // 평소엔 걸리지 않는다 — 칩 높이가 줄높이(13.1pt)보다 얇아지는 5주 달에서는
            // 글자가 줄지 않고 줄 상자 위아래 여백부터 잘린다(글자 자체는 11pt로 남는다).
            .minimumScaleFactor(0.8)
            // 이상적 폭을 그대로 받는다 — 폭이 모자라도 줄이거나 말줄임하지 않고, 넘치는
            // 만큼은 칩의 `.clipped()`가 끝에서 잘라낸다(→ `titleRow`).
            .fixedSize(horizontal: true, vertical: false)
    }

    /// 마커 + 제목 한 줄 — 시간 일정과 미리알림이 공유하는 뼈대.
    private func marked<Marker: View>(@ViewBuilder _ marker: () -> Marker) -> some View {
        // 마커가 얇은 세로 막대라 간격이 좁으면 제목의 첫 글자에 붙어 획처럼 읽힌다.
        HStack(spacing: Spacing.xs) {
            marker()
            titleRow(centered: false)
                // 완료된 할일은 한 단계 물러난다 — 지나간 일이라 지금 해야 할 것보다
                // 눈에 덜 띄어야 한다.
                .foregroundStyle(item.isCompleted ? .secondary : .primary)
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
        let size = WidgetCalendarTheme.markerSize
        // 완료됐거나 우선순위가 지정된 것은 **채운 원**, 그 외엔 테두리만.
        // 5pt짜리 마커에 체크 같은 기호를 넣으면 형태가 뭉개져 점으로만 보인다.
        if item.isCompleted || item.isHighPriority {
            // 지름을 한 단계 줄인다 — 속이 찬 원은 같은 크기여도 테두리 원보다 커 보인다.
            // 실제 크기를 맞추면 오히려 어긋나 보이므로 눈에 맞춘다.
            Circle()
                .fill(color)
                .frame(width: WidgetCalendarTheme.filledMarkerSize,
                       height: WidgetCalendarTheme.filledMarkerSize)
                // 자리는 빈 원과 같게 잡아 제목 시작점이 흔들리지 않는다.
                .frame(width: size, height: size)
        } else {
            Circle().strokeBorder(color, lineWidth: 1).frame(width: size, height: size)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: WidgetCalendarTheme.chipCornerRadius)
    }
}
