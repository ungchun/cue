//
//  MonthCalendarView.swift
//  cueLiveActivity
//
//  잠금화면 LA 왼쪽 반쪽의 월간 캘린더 — 요일 헤더 + 4~6주 그리드.
//  메모/일정 위젯이 공유한다. 날짜 계산은 `MonthCalendarGrid`, 공휴일은
//  `KoreanHolidayCalculator`(둘 다 듀얼 타깃 공유 로직)에 위임하고, 이 뷰는 그리기만 한다.
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

    /// 표시 월의 공휴일(일 숫자) — 일요일과 같은 빨강으로 칠한다.
    private var holidays: Set<Int> {
        KoreanHolidayCalculator.holidayDays(year: grid.year, month: grid.month)
    }

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
            chevron("chevron.left", delta: -1)
        }
        .overlay(alignment: .topTrailing) {
            chevron("chevron.right", delta: 1)
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
            // 오늘 표시 — WeekCalendarStrip과 같은 밑줄 바(숫자 정중앙 아래).
            Text("\(day)")
                .font(.caption2.weight(grid.isToday(day: day) ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(dayColor(day, column: column))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(grid.isToday(day: day) ? foreground : Color.clear)
                        .frame(width: 14, height: 2)
                        .offset(y: Spacing.xxs)
                }
        } else {
            Text(" ").font(.caption2)   // 빈 칸도 같은 높이 유지.
        }
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
                .glassEffect(.regular, in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
