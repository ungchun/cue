//
//  MonthWidgetView.swift
//  cueLiveActivity
//
//  월 캘린더 위젯 본문 — 요일 헤더 + 주 행 그리드. 이동형/고정형 위젯이 공유한다.
//  날짜 계산은 `MonthCalendarGrid`, 공휴일은 `KoreanHolidayCalculator`,
//  높이 예산은 `MonthWidgetMetrics`, 셀 채우기는 `MonthWidgetPacker`에 위임한다.
//
//  ⚠️ 레이아웃 원칙 — **그리드는 절대 자기 높이를 스스로 정하지 않는다.**
//  `.frame(maxHeight: .infinity)`만으로 주 행을 늘리던 시절엔, 셀마다 칩이 강제로 들어가
//  VStack의 *최소* 높이가 위젯을 넘겼고(maxHeight는 최소 높이를 줄이지 못한다) 그리드가
//  위젯 밖으로 밀려나 헤더와 마지막 주가 잘렸다. 그래서 `GeometryReader`로 실제 높이를 재고
//  행 높이를 **고정**한 뒤, 그 높이에 들어가는 칩 수를 역산한다.
//

import SwiftUI

struct MonthWidgetView: View {
    let grid: MonthCalendarGrid
    /// 표시 월의 **일(day-of-month) → 그날 항목들**. 표시 월 밖의 날은 담지 않는다.
    let itemsByDay: [Int: [WidgetCalendarItem]]

    private var holidays: Set<Int> {
        KoreanHolidayCalculator.holidayDays(year: grid.year, month: grid.month)
    }

    private var weekCount: Int { max(1, grid.weeks.count) }

    var body: some View {
        VStack(spacing: Spacing.zero) {
            // 요일 줄 위 경계선 — 아래 주 행들과 같은 선으로 격자의 위쪽 테두리를 닫는다.
            separator
            weekdayHeader
            GeometryReader { geometry in
                // 위젯 하단의 둥근 모서리가 마지막 주 칩의 좌·우 끝을 잘라먹는다(실기기 확인).
                // 모서리 반경만큼 격자 전체를 들이면 셀이 좁아지므로 아래만 비운다 — 다만
                // **예산에서 먼저 빼야** 한다. VStack에 패딩으로 주면 행 높이 합이 이미 전체
                // 높이라 패딩이 아래로 넘쳐 오히려 더 잘린다.
                let usableHeight = max(0, geometry.size.height - Spacing.smd)
                // 구분선이 먹는 높이를 떼고 남은 만큼을 주 행이 균등하게 나눈다.
                let rowHeight = max(
                    0,
                    (usableHeight - WidgetCalendarTheme.hairline * CGFloat(weekCount)) / CGFloat(weekCount)
                )
                // 칸 수는 주 수가 정하고(5주 3개·6주 2개), 칩 높이가 그 개수에 맞춰 눌린다.
                let slots = MonthWidgetMetrics.slotCount(weekCount: weekCount)
                let chipHeight = MonthWidgetMetrics.chipHeight(rowHeight: rowHeight, slots: slots)

                VStack(spacing: Spacing.zero) {
                    ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                        separator
                        weekRow(
                            week,
                            slots: slots,
                            chipHeight: chipHeight,
                            columnWidth: geometry.size.width / CGFloat(max(1, week.count))
                        )
                            // 고정 높이 — 자식이 아무리 커도 행이 밀려나지 않는다.
                            .frame(height: rowHeight)
                            .clipped()
                    }
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(WidgetCalendarTheme.gridLine)
            .frame(height: WidgetCalendarTheme.hairline)
    }

    private var weekdayHeader: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { column, symbol in
                Text(symbol)
                    .font(.caption2)
                    // caption2가 램프의 바닥이라 그 아래 미세 조정은 scaleEffect뿐이다.
                    // textScale 한 단계는 너무 작아 요일이 격자에 묻힌다.
                    .scaleEffect(0.92)
                    .foregroundStyle(WidgetCalendarTheme.weekdayColor(grid.weekdayIndex(column: column)))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, Spacing.xxs)
    }

    /// 한 주 행 — 날짜 숫자 줄 + 칸(lane)별 가로 막대.
    ///
    /// ⚠️ 셀마다 칩을 그리지 않는다. 여러 날에 걸친 일정은 **여러 칸을 가로지르는 막대 하나**여야
    /// 제목도 하나만 나온다. 셀 단위로 그리면 3일짜리 일정이 제목까지 세 번 반복된다.
    private func weekRow(
        _ week: [Int?],
        slots: Int,
        chipHeight: CGFloat,
        columnWidth: CGFloat
    ) -> some View {
        // 배치는 **주 단위**로 한 번에 — 걸치는 일정이 모든 날에서 같은 칸에 앉아야 이어진다.
        let layout = MonthWeekPacker.pack(days: week, itemsByDay: itemsByDay, slots: slots)
        return VStack(spacing: MonthWidgetMetrics.chipSpacing) {
            dayNumberRow(week, layout: layout, columnWidth: columnWidth)
                .padding(.bottom, MonthWidgetMetrics.dayNumberGap - MonthWidgetMetrics.chipSpacing)
            ForEach(0..<max(0, slots), id: \.self) { lane in
                laneRow(week, layout: layout, lane: lane, columnWidth: columnWidth, height: chipHeight)
            }
            Spacer(minLength: Spacing.zero)
        }
        // 세로 그리드는 막대 위가 아니라 **아래**에 깔린다 — 스팬 막대가 열 경계를 가로질러야
        // 하나로 이어져 보이는데, 선이 위에 있으면 막대가 토막나 보인다.
        .background(alignment: .topLeading) {
            verticalGrid(columnCount: week.count, columnWidth: columnWidth)
        }
    }

    /// 날짜 숫자 한 줄 — 열마다 하나씩.
    private func dayNumberRow(
        _ week: [Int?],
        layout: MonthWeekLayout,
        columnWidth: CGFloat
    ) -> some View {
        HStack(spacing: Spacing.zero) {
            ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                Group {
                    if let day {
                        dayNumber(day, column: column, overflow: layout.overflow(forDay: day))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth)
            }
        }
    }

    /// 칸 하나의 가로 줄 — 이어지는 구간마다 막대 하나.
    private func laneRow(
        _ week: [Int?],
        layout: MonthWeekLayout,
        lane: Int,
        columnWidth: CGFloat,
        height: CGFloat
    ) -> some View {
        HStack(spacing: Spacing.zero) {
            ForEach(MonthWeekPacker.runs(week: week, layout: layout, lane: lane)) { run in
                Group {
                    if let item = run.item {
                        WidgetItemChip(
                            item: item,
                            height: height,
                            isSpanning: run.isSpanning
                        )
                        // 세로 칩 간격과 같은 값만 들여 가로·세로 여백을 맞춘다.
                        .padding(.horizontal, MonthWidgetMetrics.chipSpacing)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: columnWidth * CGFloat(run.length))
            }
        }
        .frame(height: height)
    }

    /// 열 경계의 세로 그리드 — 마지막 열 오른쪽엔 긋지 않는다(위젯 가장자리와 겹친다).
    private func verticalGrid(columnCount: Int, columnWidth: CGFloat) -> some View {
        HStack(spacing: Spacing.zero) {
            ForEach(0..<max(1, columnCount), id: \.self) { column in
                Color.clear
                    .frame(width: columnWidth)
                    .overlay(alignment: .trailing) {
                        if column < columnCount - 1 {
                            Rectangle()
                                .fill(WidgetCalendarTheme.gridLine)
                                .frame(width: WidgetCalendarTheme.hairline)
                        }
                    }
            }
        }
    }

    /// 날짜 숫자 줄 — 숫자는 셀 **오른쪽 끝**, 숨은 항목 배지는 **왼쪽 끝**(레퍼런스와 동일).
    ///
    /// 예전엔 숫자를 가운데 두고 배지를 overlay로 겹쳐 놨는데, 셀 폭이 45pt뿐이라 "+3"과
    /// "27"이 서로 파고들어 "+327"처럼 읽혔다. 양 끝으로 벌리면 겹칠 수가 없다.
    private func dayNumber(_ day: Int, column: Int, overflow: Int) -> some View {
        HStack(spacing: Spacing.xxs) {
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.caption)
                    // 날짜 숫자보다 **작아야** 한다 — 숨은 개수는 보조 정보다.
                    // textScale은 한 단계뿐이라 그보다 더 줄이는 수단은 scaleEffect밖에 없다.
                    // 레이아웃 폭은 원래 크기대로 잡히지만 배지 오른쪽은 Spacer가 흡수한다.
                    .textScale(.secondary)
                    .scaleEffect(0.85, anchor: .leading)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Spacing.zero)
            Text("\(day)")
                // 오늘도 굵게 하지 않는다 — 밑줄 바가 이미 오늘을 가리키므로 굵기까지 더하면
                // 그 셀만 무거워져 격자의 리듬이 깨진다.
                .font(.caption2)
                // caption2가 램프의 바닥이라 그 아래로 내리는 수단은 scaleEffect뿐이다.
                // textScale 한 단계(11→8.8pt)는 과해서 `+N` 배지와 크기가 겹친다.
                // 날짜는 셀 오른쪽 끝에 붙으므로 축소 기준점도 trailing이어야 자리가 안 밀린다.
                .scaleEffect(0.9, anchor: .trailing)
                .monospacedDigit()
                .foregroundStyle(
                    WidgetCalendarTheme.weekdayColor(
                        grid.weekdayIndex(column: column),
                        isHoliday: holidays.contains(day)
                    )
                )
                // 오늘 표시 — 밑줄 폭을 **숫자 글자 폭에 맞춘다**. 고정 폭을 주면 한 자리 수
                // 날짜에서 밑줄이 숫자를 삐져나온다(LA 온보딩 캘린더에서 겪은 것과 같은 문제).
                //
                // 오프셋도 주지 않는다. 숫자엔 디센더가 없어 줄 상자 아래에 이미 여백이 있고,
                // 거기에 그대로 얹으면 아래 칩을 침범하지 않는다 — 예산에 밑줄 몫을 따로
                // 잡지 않아도 되므로 5주 달에서 칩 한 칸을 더 벌 수 있다.
                .overlay(alignment: .bottom) {
                    if grid.isToday(day: day) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary)
                            .frame(height: WidgetCalendarTheme.todayUnderlineHeight)
                    }
                }
        }
        // 숫자가 세로 그리드 선에 붙지 않게 — 붙어 있으면 실제 크기보다 커 보이고 옆 셀
        // 숫자와 뭉쳐 읽힌다. 셀에 이미 들어간 패딩만큼 뺀 나머지를 여기서 준다.
        .padding(.horizontal, Spacing.xs - MonthWidgetMetrics.chipSpacing)
        .frame(maxWidth: .infinity)
        .frame(height: MonthWidgetMetrics.dayNumberHeight)
    }
}
