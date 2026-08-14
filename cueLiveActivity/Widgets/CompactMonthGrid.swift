//
//  CompactMonthGrid.swift
//  cueLiveActivity
//
//  좁은 칸에 들어가는 월 격자 — 날짜 숫자 + 그날 항목을 알리는 점.
//  작은 캘린더 위젯과, 사이드 목록 위젯의 왼쪽 절반이 공유한다.
//

import SwiftUI

/// 제목 칩 없이 **점**으로만 항목을 알리는 월 격자.
///
/// 큰 위젯의 `MonthWidgetView`를 쓰지 않는 이유: 그쪽은 셀마다 제목 칩이 들어가는 걸
/// 전제로 행 높이를 예산한다. 폭 170pt(작은 위젯) / 168pt(사이드 목록 위젯의 왼쪽)에서는
/// 셀이 20pt 남짓이라 제목이 한 글자도 안 들어가고("일정"이 "일ㅈ"으로 잘렸다),
/// 높이 170pt에는 그 예산 자체가 들어가지 않아 마지막 주가 위젯 밖으로 밀려났다.
///
/// 이 크기에서 전할 수 있는 건 "그날 뭔가 있다"까지다. 그 이상은 옆 목록이나 큰 위젯의 몫.
struct CompactMonthGrid: View {
    let grid: MonthCalendarGrid
    /// 표시 월의 **일 숫자 → 그날 항목들**.
    let itemsByDay: [Int: [WidgetCalendarItem]]
    /// 표시 월의 공휴일(일 숫자) — 날짜 숫자를 빨갛게 칠하는 근거.
    let holidays: Set<Int>

    private var weekCount: Int { max(1, grid.weeks.count) }

    /// 격자 좌우 여백 — 폭에 대한 비율.
    ///
    /// 간격이 아니라 **레이아웃 치수**라 `Spacing` 토큰을 쓰지 않는다. 비율인 이유는
    /// 이 뷰가 폭이 다른 두 위젯(작은 캘린더 ~150pt, 사이드 위젯 ~170pt)에서 함께 쓰여서다.
    private static let horizontalInsetRatio: CGFloat = 0.04
    /// 격자 위아래 여백 — 높이에 대한 비율. 가로보다 작게 잡는다: 6주 달은 행이 이미
    /// 빠듯해서 같은 비율로 빼면 날짜가 눌린다.
    private static let verticalInsetRatio: CGFloat = 0.03

    /// 요일 글자 축소율 — 뷰와 높이 예산이 **같은 값**을 써야 빈 자리가 안 생긴다.
    ///
    /// 1.0에 가까울수록 요일이 날짜와 비슷해져 격자의 머리글로 읽히지 않는다.
    /// 날짜(`caption2`)보다는 작되 읽히는 선.
    private static let weekdayScale: CGFloat = 0.88

    var body: some View {
        // 높이를 **재서 나눈다.**
        //
        // `minHeight`/`maxHeight: .infinity`로는 안 된다 — 그건 한계만 정할 뿐,
        // 셀의 **고유 높이**가 여전히 바닥이라 6주 × 그 바닥이 위젯보다 크면 그대로
        // 넘친다(실기기에서 위아래가 살짝 넘쳤다). 잰 높이를 주 수로 정확히 나눠
        // 넘겨야 행이 실제로 눌린다.
        //
        // 여기서 `GeometryReader`가 안전한 이유: 이 뷰는 부모가 폭·높이를 확정해 주는
        // 자리에 놓인다(작은 캘린더는 `VStack`의 마지막 칸, 사이드 위젯은 `HStack`의 한 칸).
        GeometryReader { geometry in
            // 요일 줄 높이는 **축소된 글자 크기**로 잡는다.
            //
            // `scaleEffect`는 레이아웃 크기를 바꾸지 않아서, 줄높이 그대로(13.1pt) 주면
            // 실제 글자(0.78배 ≈ 10pt)보다 3pt가 남아 위아래로 갈라진다. 그 위쪽 몫이
            // 제목과 요일 줄 사이를 벌렸다.
            let headerHeight = CompactMonthMetrics.dayNumberLine * Self.weekdayScale
            // 아래 여백을 **먼저 빼고** 나눈다. 남는 높이 전체를 나누면 그 여백만큼
            // 넘쳐 마지막 주가 카드 밖으로 밀린다.
            //
            // 위쪽은 빼지 않는다 — 그 여백이 제목과 요일 줄 사이를 벌려, 제목이 격자에서
            // 떨어져 보였다. 제목은 격자의 머리글이라 붙어 있어야 한다.
            let inset = geometry.size.height * Self.verticalInsetRatio
            let gridHeight = geometry.size.height - inset
            let rowSlot = max(1, (gridHeight - headerHeight) / CGFloat(weekCount))

            VStack(spacing: Spacing.zero) {
                weekdayHeader
                    .frame(height: headerHeight)
                ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: Spacing.zero) {
                        ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                            Group {
                                if let day {
                                    dayCell(day, column: column)
                                } else {
                                    Color.clear
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    // 행 몫을 **못 박는다** — 잰 높이를 나눈 값이라 합이 정확히 격자 높이다.
                    //
                    // `.clipped()`는 걸지 않는다. 점이 날짜 줄 상자 밖(디센더 자리)에
                    // 얹히므로 여기서 자르면 점이 통째로 사라진다.
                    .frame(height: rowSlot)
                }
            }
            // 격자를 좌우·위아래로 조금 좁힌다 — 카드를 끝까지 쓰면 열과 행이 성기게
            // 퍼져 달력이 아니라 표처럼 보인다(레퍼런스는 사방에 여백이 있다).
            //
            // 크기에 **비례**해 좁힌다. 고정값을 빼면 작은 캘린더(폭·높이 좁음)에서는
            // 과하게 좁아지고 사이드 위젯에서는 티가 안 난다.
            .padding(.horizontal, geometry.size.width * Self.horizontalInsetRatio)
            // 아래만 준다 — 위에 주면 제목과 요일 줄 사이가 벌어진다(위 `inset` 주석 참고).
            .padding(.bottom, geometry.size.height * Self.verticalInsetRatio)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    /// 요일 줄 — 구분선은 긋지 않는다. 이 크기에서는 선이 숫자만큼의 잉크를 써서
    /// 격자가 먼저 읽히고 정작 날짜가 뒤로 밀린다.
    private var weekdayHeader: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { column, symbol in
                Text(symbol)
                    .font(.caption2)
                    .scaleEffect(Self.weekdayScale)
                    .foregroundStyle(WidgetCalendarTheme.weekdayColor(grid.weekdayIndex(column: column)))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, Spacing.xxs)
    }

    /// 날짜 숫자 + 그 아래 점들.
    ///
    /// 점은 **주 수와 무관하게 항상** 그린다. 그날 뭔가 있다는 표시가 이 위젯의 유일한
    /// 정보라, 6주 달에만 사라지면 그 달에는 빈 달력을 보게 된다. 대신 행 높이를
    /// 주 수에서 역산해(→ `CompactMonthMetrics`) 6주여도 점까지 들어가게 맞춘다.
    private func dayCell(_ day: Int, column: Int) -> some View {
        Text("\(day)")
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(
                WidgetCalendarTheme.weekdayColor(
                    grid.weekdayIndex(column: column),
                    isHoliday: holidays.contains(day)
                )
            )
            .padding(CompactMonthMetrics.dayNumberPadding(weekCount: weekCount))
            // 오늘은 **숫자 밑줄**로 표시한다 — 큰 위젯(`MonthWidgetView`)과 같은 표현이라
            // 위젯 묶음 안에서 "오늘"이 한 가지 모양으로 읽힌다.
            //
            // 폭을 숫자 글자 폭에 맞춘다. 고정 폭을 주면 한 자리 수 날짜에서 밑줄이
            // 숫자를 삐져나온다.
            .overlay(alignment: .bottom) {
                if grid.isToday(day: day) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.primary)
                        .frame(height: WidgetCalendarTheme.todayUnderlineHeight)
                        // 점이 앉는 자리(디센더)보다 위에 긋는다 — 겹치면 밑줄이
                        // 점처럼 두꺼워 보인다.
                        .padding(.horizontal, CompactMonthMetrics.dayNumberPadding(weekCount: weekCount))
                }
            }
            // 점을 날짜 **아래에 붙여** 그린다.
            //
            // 별도의 줄로 쌓지 않는다 — 쌓으면 행마다 4pt, 6주면 24pt가 더 드는데 가장
            // 좁은 기기(141pt)에는 그 자리가 없다. 숫자에는 디센더가 없어 줄 상자 아래가
            // 늘 비므로, 점을 그 자리로 끌어올려 공짜 높이를 쓴다
            // (오늘 밑줄을 같은 자리에 얹는 `MonthWidgetView`와 같은 수법).
            .overlay(alignment: .bottom) {
                // 오늘은 점을 찍지 않는다 — 밑줄이 이미 그 자리에 있어 둘이 겹치면
                // 밑줄이 두꺼워 보이고 무슨 표시인지 갈리지 않는다.
                if !grid.isToday(day: day) {
                    dots(for: day)
                        // 디센더 몫만큼 올려 앉힌다 — 그만큼이 행 예산에서 아낀 높이다.
                        .offset(y: CompactMonthMetrics.dotSize - CompactMonthMetrics.dayNumberDescender)
                }
            }
            .frame(maxHeight: .infinity)
    }

    /// 그날 항목을 알리는 점 — **캘린더 색마다 하나씩**, 최대 `maximumDots`개.
    ///
    /// 개수가 아니라 "무엇이 있는지"를 색으로 전한다(레퍼런스와 같은 표현). 같은 캘린더
    /// 일정이 세 건이어도 점은 하나다 — 20pt 폭에 점 셋이 붙으면 하나의 선으로 보이고,
    /// 그 길이 차를 읽어낼 사람은 없다.
    private func dots(for day: Int) -> some View {
        HStack(spacing: Self.dotGap) {
            ForEach(colors(for: day), id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex) ?? .accentColor)
                    .frame(width: CompactMonthMetrics.dotSize, height: CompactMonthMetrics.dotSize)
            }
        }
        // 점이 없는 날도 같은 높이를 차지한다 — 없으면 그 셀만 날짜가 아래로 처진다.
        .frame(height: CompactMonthMetrics.dotSize)
    }

    /// 그날 항목의 캘린더 색들 — 중복은 접고 등장 순서를 지킨다.
    private func colors(for day: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in itemsByDay[day] ?? [] {
            // 색이 없는 항목은 뷰가 accent로 폴백하므로 키도 하나로 묶는다.
            let hex = item.colorHex ?? Self.accentKey
            guard seen.insert(hex).inserted else { continue }
            result.append(hex)
            if result.count == Self.maximumDots { break }
        }
        return result
    }

    /// 색이 없는 항목을 한 묶음으로 세는 키 — hex가 아니라서 실제 색과 부딪히지 않는다.
    private static let accentKey = "accent"
    /// 한 셀에 찍는 점의 최대 개수 — 셀 폭이 20pt 남짓이라 셋을 넘기면 서로 붙는다.
    private static let maximumDots = 3
    /// 점 **사이** 가로 간격. 세로 높이를 정하는 값(지름·줄 간격)은 예산과 갈라지면
    /// 안 되므로 `CompactMonthMetrics`가 단일 출처다.
    private static let dotGap: CGFloat = 1.5
}
