//
//  MonthCalendarView.swift
//  cueLiveActivity
//
//  잠금화면 LA 왼쪽 반쪽의 월간 캘린더 — 요일 헤더 + 4~6주 그리드.
//  메모/일정 위젯이 공유한다. 날짜 계산은 `MonthCalendarGrid`(듀얼 타깃 공유 로직)에
//  위임하고, 일정 점·공휴일은 ContentState로 받아, 이 뷰는 그리기만 한다.
//
//  월 이동은 좌우 ‹ › 셰브런(Button(intent:)) — 잠금화면 공간이 좁아 레이아웃에 끼우지 않고
//  overlay로 공중에 띄운다(공간 미점유, 흐릿하게). 현재 월은 그리드 뒤 고스트 워터마크.
//

import AppIntents
import SwiftUI

struct MonthCalendarView: View {
    let grid: MonthCalendarGrid
    /// 셰브런 탭이 어느 LA를 움직일지 — `ShiftCalendarMonthIntent.memoTarget`/`scheduleTarget`.
    let intentTarget: String
    /// 기본은 시스템 컬러. 메모 LA는 카드가 사용자 색이라 사용자 글자색을 주입한다.
    var foreground: Color = .primary
    var secondaryForeground: Color = .secondary
    /// 표시 월의 날짜별 점(일 정수 기준) — 각 날 숫자 아래에 캘린더·할일 목록 색 동그라미.
    /// 일정과 할일을 함께, 한 건당 한 점 센다(→ `MonthDotColors`).
    /// 오늘은 밑줄로 표시하므로 점에서 제외.
    var eventDots: [LiveMonthDot] = []
    /// 표시 월의 공휴일(일 숫자) — 일요일과 같은 빨강으로 칠한다.
    ///
    /// **앱이 게시 시점에 사용자 캘린더에서 뽑아 실어 보낸 값**이다(→ `HolidayEventPolicy`).
    /// LA 위젯은 렌더 시점에 EventKit을 읽을 수 없어 여기서 직접 조회할 수 없다.
    var holidays: [Int] = []
    /// 월 이동 셰브런 표시 여부 — 온보딩 목업의 정적 캘린더는 false로 이동을 막는다.
    var allowsMonthShift: Bool = true

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            weekdayHeader
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                weekRow(week)
                    // 남는 세로 공간을 주 행들이 고르게 나눠 가져 하단 빈 여백을 없앤다
                    // (카드 높이는 오른쪽 본문이 결정 — 캘린더가 그 높이에 맞춰 늘어난다).
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 고스트 월 — 숫자 뒤(background)에 깔아 공간을 차지하지 않는다.
        .background(alignment: .top) {
            Text(grid.monthLabel)
                .font(.callout.weight(.bold))
                .foregroundStyle(foreground.opacity(0.15))
                .allowsHitTesting(false)
        }
        // 셰브런은 상단 좌우 모서리(스크린샷의 ‹ 자리) — 그리드 숫자와 겹침 최소화.
        .overlay(alignment: .topLeading) {
            if allowsMonthShift { chevron("chevron.left", delta: -1) }
        }
        .overlay(alignment: .topTrailing) {
            if allowsMonthShift { chevron("chevron.right", delta: 1) }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: Spacing.zero) {
            ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(secondaryForeground)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekRow(_ week: [Int?]) -> some View {
        HStack(spacing: Spacing.zero) {
            ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                dayCell(day, column: column)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Int?, column: Int) -> some View {
        if let day {
            VStack(spacing: 1) {
                // 오늘 표시 — WeekCalendarStrip과 같은 밑줄 바(숫자 정중앙 아래).
                Text("\(day)")
                    .font(.footnote.weight(grid.isToday(day: day) ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(dayColor(day, column: column))
                    .overlay(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(grid.isToday(day: day) ? foreground : Color.clear)
                            .frame(width: 14, height: 2)
                            .offset(y: Spacing.xxs)
                    }
                // 점 — 그날 항목 한 건당 하나(일정·할일 공통). 오늘은 빌더에서 제외돼 점 없음.
                dots(for: day)
            }
        } else {
            Text(" ").font(.footnote)   // 빈 칸도 같은 높이 유지.
        }
    }

    /// 날짜 숫자 아래 점 한 줄 — 좁은 셀이라 작게(3pt). 점이 없어도 같은 높이를 예약해
    /// 모든 셀의 숫자가 같은 세로 기준선에 정렬되게 한다.
    private func dots(for day: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(Array(colorHexes(forDay: day).enumerated()), id: \.offset) { _, hex in
                Circle()
                    .fill(Color(hex: hex) ?? foreground)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(height: 3)
    }

    /// 그날(표시 월 기준 일 숫자)의 점 색 목록 — `eventDots`는 표시 월만 담아 일 숫자로 매칭.
    private func colorHexes(forDay day: Int) -> [String] {
        eventDots.first { $0.day == day }?.colorHexes ?? []
    }

    /// 일요일·공휴일 빨강, 토요일 옅게, 평일은 본문 색.
    private func dayColor(_ day: Int, column: Int) -> Color {
        let weekday = grid.weekdayIndex(column: column)
        if weekday == 1 || holidays.contains(day) { return .red }
        if weekday == 7 { return secondaryForeground }
        return foreground
    }

    /// 월 이동 셰브런 — 리퀴드 글래스 원형 칩, overlay로 공간 미점유. 탭 영역은 패딩으로 확보.
    private func chevron(_ systemName: String, delta: Int) -> some View {
        Button(intent: ShiftCalendarMonthIntent(targetRaw: intentTarget, delta: delta)) {
            Image(systemName: systemName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(secondaryForeground)
                .padding(Spacing.xs)
                // glassEffect는 LA 위젯에서 렌더되지 않아(아예 안 보임) 반투명 원형 칩으로 유리
                // 느낌만 낸다 — 색 opacity 조합은 위젯에서 항상 렌더가 보장된다.
                .background(Circle().fill(foreground.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
