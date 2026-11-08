//
//  ScheduleMonthWeekRow.swift
//  cue / Presentation
//

import SwiftUI

/// 월 격자의 한 주 — 7칸을 세로 구분선으로 나눠 나란히 둔다.
///
/// 7칸은 항상 같은 높이다. 항목이 가장 많은 날에 맞춰 그 주 전체가 늘어나야 세로 구분선이
/// 끊기지 않고 행이 한 줄로 읽힌다.
struct ScheduleMonthWeekRow: View {
    /// 이 주가 속한 달 — 항목·격자를 여기서 읽어 달 단위로만 다시 그려진다.
    let page: ScheduleMonthPageModel
    /// 이 주의 7칸 — 표시 월 밖은 nil.
    let week: [Int?]
    /// 화면을 채우기 위한 행 높이 하한 — 항목이 적은 달도 격자가 화면 아래까지 차 보이게.
    let fillHeight: CGFloat
    /// 칩 탭 — 상세 시트를 연다.
    let onSelect: (WidgetCalendarItem) -> Void

    /// 빈 주도 날짜 숫자 + 칩 3줄 정도는 차지한다 — 주마다 높이가 들쭉날쭉하면 격자로 안 읽힌다.
    /// 글자 크기를 키우면 칩도 커지므로 caption2 기준으로 함께 늘린다.
    @ScaledMetric(relativeTo: .caption2) private var minimumHeight: CGFloat = 84
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(week.indices, id: \.self) { column in
                if column > 0 {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1 / displayScale)
                }
                cell(column: column)
                    // 모든 칸이 행 높이를 채우게 — 아래 fixedSize가 정한 행 높이(가장 큰 칸)로 늘어난다.
                    .frame(maxWidth: .infinity, minHeight: max(minimumHeight, fillHeight), maxHeight: .infinity, alignment: .top)
            }
        }
        // 행 높이 = 칸들의 자연 높이 중 최댓값. 이게 없으면 maxHeight: .infinity 칸이 무한히 늘어나려 한다.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cell(column: Int) -> some View {
        let day = week[column]
        return ScheduleMonthDayCell(
            day: day,
            weekday: page.grid.weekdayIndex(column: column),
            isToday: day.map { page.grid.isToday(day: $0) } ?? false,
            weatherSymbol: day.flatMap { page.weatherSymbol(day: $0) },
            lunarLabel: day.flatMap { page.lunarLabel(day: $0) },
            items: day.map { page.items(day: $0) } ?? [],
            onSelect: onSelect
        )
    }
}
