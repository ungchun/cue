//
//  MonthWidgetView.swift
//  cueLiveActivity
//
//  월 캘린더 위젯 본문 — 요일 헤더 + 주 행 그리드. 이동형/고정형 위젯이 공유한다.
//  날짜 계산은 `MonthCalendarGrid`, 높이 예산은 `MonthWidgetMetrics`,
//  셀 채우기는 `MonthWidgetPacker`에 위임한다.
//
//  ⚠️ 레이아웃 원칙 — **그리드는 절대 자기 높이를 스스로 정하지 않는다.**
//  `.frame(maxHeight: .infinity)`만으로 주 행을 늘리던 시절엔, 셀마다 칩이 강제로 들어가
//  VStack의 *최소* 높이가 위젯을 넘겼고(maxHeight는 최소 높이를 줄이지 못한다) 그리드가
//  위젯 밖으로 밀려나 헤더와 마지막 주가 잘렸다. 그래서 `GeometryReader`로 실제 높이를 재고
//  행 높이를 **고정**한 뒤, 그 높이에 들어가는 칩 수를 역산한다.
//

import SwiftUI

struct MonthWidgetView: View {
    /// 격자 아래 남기는 카드 바닥 여백.
    ///
    /// 헤더가 제목 줄에 주는 위쪽 패딩(`Spacing.xs`)과 같은 값이다.
    ///
    /// 높이 **예산에서 빼는** 값이라 `Spacing` 토큰이 아니라 여기 둔다 — 간격이 아니라
    /// 레이아웃 치수다(`WidgetCalendarTheme`의 거터·마커 크기와 같은 성격).
    static let bottomInset: CGFloat = Spacing.xs

    let grid: MonthCalendarGrid
    /// 표시 월의 **일(day-of-month) → 그날 항목들**. 표시 월 밖의 날은 담지 않는다.
    let itemsByDay: [Int: [WidgetCalendarItem]]
    /// 표시 월의 공휴일(일 숫자) — 사용자가 구독한 공휴일 캘린더에서 나온다(→ `HolidayEventPolicy`).
    ///
    /// `itemsByDay`와 따로 받는 이유: 잠긴 위젯은 항목을 통째로 비워 넘기는데(유료 내용 차단)
    /// 공휴일 색까지 같이 사라지면 무료 사용자에게는 격자가 평일뿐인 달력이 된다.
    let holidays: Set<Int>

    private var weekCount: Int { max(1, grid.weeks.count) }

    var body: some View {
        VStack(spacing: Spacing.zero) {
            // 요일 줄 위 경계선은 여기서 그리지 않는다 — 공통 헤더가 자기 아래 구분선을
            // 소유하며, 그 선이 곧 격자의 위쪽 테두리다(위젯 4종 공통).
            weekdayHeader
            GeometryReader { geometry in
                // 행 높이는 **SwiftUI가 나눈다** — `maxHeight: .infinity`로 남는 높이를
                // 균등 분배시킨다. 예전엔 여기서 직접 나눠 `.frame(height:)`로 박았는데,
                // 자식이 예산보다 조금이라도 크면 VStack이 그만큼 넘쳐 마지막 주가
                // GeometryReader 밖으로 밀려났다(GeometryReader는 자식을 클립하지 않는다).
                // 그 결과가 "닫히지 않는 하단 여백"이었다 — 실제로는 여백이 아니라
                // 마지막 주가 통째로 화면 밖에 있었던 것.
                //
                // 칩 높이 예산은 그대로 필요하다 — 칸 수를 주 수가 고정하기 때문에
                // 칩이 그 개수에 맞춰 눌려야 한다. 다만 예산이 어긋나도 이제는 행이
                // 자기 몫만 차지하고 `.clipped()`가 잘라낼 뿐, 격자가 밀려나지 않는다.
                // 카드 바닥에 숨 쉴 틈을 남긴다 — 마지막 주 칩이 모서리에 바로 닿으면
                // 격자가 카드 밖으로 이어지는 것처럼 답답해 보인다.
                // **예산에서 먼저 뺀다**. 바깥에 패딩으로 주면 행 높이 합이 이미 전체
                // 높이라 그만큼 아래로 넘쳐 마지막 주가 잘린다.
                let usableHeight = max(0, geometry.size.height - Self.bottomInset)
                let rowHeight = max(
                    0,
                    (usableHeight - WidgetCalendarTheme.hairline * CGFloat(weekCount))
                        / CGFloat(weekCount)
                )
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
                            // 남는 높이를 행들이 균등하게 나눠 갖는다 — 합이 정확히
                            // GeometryReader 높이라 마지막 주가 바닥에 닿는다.
                            .frame(maxHeight: .infinity)
                            .clipped()
                    }
                }
                // 자식이 넘치더라도 격자가 위젯 밖으로 밀려나지 않게 못 박는다.
                // 높이는 `usableHeight` — 남는 `bottomInset`이 카드 바닥 여백이 된다.
                .frame(height: usableHeight, alignment: .top)
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
                    .scaleEffect(0.88)
                    .foregroundStyle(WidgetCalendarTheme.weekdayColor(grid.weekdayIndex(column: column)))
                    .frame(maxWidth: .infinity)
            }
        }
        // 위아래를 **같은 값으로** 준다. 예전엔 아래만 줬는데, 위 여백은 바깥 VStack의
        // spacing에서 간접적으로 오다 보니 구분선 바로 아래는 사실상 0이었다 —
        // 요일 글자가 위 선에 붙고 아래만 떠 보였다(실기기 확인).
        .padding(.vertical, Spacing.xxs)
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
            // Spacer를 두지 않는다 — 칩이 행 높이를 나눠 가지므로 남는 높이가 없다.
            // 예전엔 칩 높이에 상한이 있어 남는 몫을 Spacer가 행 아래로 몰았고,
            // 마지막 주에서 그게 카드 바닥의 빈 공간으로 보였다.
        }
        // 예산과 실제 렌더가 어긋나도 행이 자기 몫보다 커지지 않게 한다 — 넘치는 쪽은
        // 바깥 `.clipped()`가 잘라낸다. 이게 없으면 오차가 누적돼 마지막 주가 밀려난다.
        .frame(maxHeight: .infinity, alignment: .top)
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
