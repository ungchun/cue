//
//  MemoLivePreviewCard.swift
//  cue / Presentation
//
//  설정 메모 섹션의 라이브 액티비티 미리보기 — 글자 크기·배경색·글자색·캘린더 함께 보기
//  설정에 따라 메모 LA가 잠금화면에서 어떻게 보일지 실시간으로 흉내낸다.
//
//  실제 LA 위젯(`MemoLiveActivityWidget`)은 위젯 익스텐션 타깃 전용이라 메인 앱에서
//  재사용할 수 없다. 그래서 같은 레이아웃(카드 = 배경색, 가운데 큰 텍스트 = 글자색,
//  캘린더 ON이면 좌 캘린더·우 텍스트 분할)을 이 뷰가 다시 그린다. 캘린더는 실데이터가
//  아니라 이번 달 빈 그리드(점·공휴일·셰브런 없음) 하나로 표시한다.
//
//  큰 헤드라인은 위젯과 동일하게 `.system(size:)` 고정 크기를 쓴다 — LA 카드가 폭을 꽉
//  채우는 문법을 미리보기가 정확히 재현해야 하므로, LA 한정 디자인 예외를 그대로 따른다.
//

import SwiftUI

/// 메모 LA 미리보기 카드. 입력은 설정 화면이 이미 들고 있는 실시간 값이라 조절 즉시 반영된다.
struct MemoLivePreviewCard: View {
    let text: String
    let backgroundColor: Color
    let fontColor: Color
    let textSize: MemoTextSize
    let showsCalendar: Bool

    /// 카드 코너 반경 — Spacing 토큰이 아니라 List 셀 마스크 반경(≈26)에 종속된 값이라 따로 둔다.
    private static let cardCornerRadius: CGFloat = 28

    /// 카드에 실을 문구 — 빈 메모면 샘플로 대체(설정 화면은 편집면이 아니라 표시용).
    private var displayText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "What to remember?") : trimmed
    }

    var body: some View {
        // 단일 RoundedRectangle에 배경색을 채우고 같은 모양으로 테두리를 그린다 —
        // fill·clip·stroke를 겹치면 모서리에서 clip이 리스트 배경을 비쳐 "잘림"이 생겨, 한 겹으로 둔다.
        // 테두리는 균일한 반투명 흰 선 — 그라데이션은 옅어지는 쪽 모서리가 끊겨 보여 균일색으로 돈다.
        // 반경 28 — List 셀 코너 마스크(inset grouped, iOS 26 ≈ 26)보다 크게. 카드 반경 ≥ 마스크
        // 반경이면 카드 모서리가 항상 마스크 안쪽이라 대각선 잘림이 기하학적으로 불가능하다.
        let shape = RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
        return card
            .frame(maxWidth: .infinity)
            // 실제 LA와 동일 — 캘린더 ON이면 카드가 최대 높이로 늘어나고, 텍스트 단독이면
            // 텍스트 높이에 맞춰 줄어든다.
            .frame(height: showsCalendar ? 156 : nil)
            .background(backgroundColor, in: shape)
            .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }

    @ViewBuilder
    private var card: some View {
        if showsCalendar {
            HStack(alignment: .center, spacing: Spacing.md) {
                emptyCalendar
                    .frame(maxWidth: .infinity)
                bigText(size: 32 * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        } else {
            // 텍스트 단독 — 위젯과 같은 패딩만 두고 높이는 텍스트가 결정한다.
            bigText(size: 44 * scale)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.lg)
        }
    }

    /// 카드를 채우는 큰 텍스트 — 위젯 `bigText`와 동일 규칙(heavy rounded, 좌측정렬, 축소).
    private func bigText(size: CGFloat) -> some View {
        Text(displayText)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(fontColor)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            .minimumScaleFactor(0.5)
    }

    // MARK: - 빈 캘린더

    /// 이번 달 빈 월간 그리드 — 요일 헤더 + 날짜 숫자만. 일정 점·공휴일·셰브런은 없다.
    /// 색은 카드가 사용자 배경색이라 시스템 컬러 대신 사용자 글자색 계열을 쓴다(위젯과 동일 문법).
    private var emptyCalendar: some View {
        let grid = MonthCalendarGrid(now: .now, monthOffset: 0)
        return VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.zero) {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(fontColor.opacity(0.55))
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: Spacing.zero) {
                    ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                        dayCell(grid: grid, day: day, column: column)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func dayCell(grid: MonthCalendarGrid, day: Int?, column: Int) -> some View {
        if let day {
            Text("\(day)")
                .font(.footnote.weight(grid.isToday(day: day) ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(dayColor(grid: grid, day: day, column: column))
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(grid.isToday(day: day) ? fontColor : Color.clear)
                        .frame(width: 14, height: 2)
                        .offset(y: Spacing.xxs)
                }
        } else {
            Text(" ").font(.footnote)
        }
    }

    /// 일요일 빨강, 토요일 옅게, 평일은 글자색. (공휴일은 빈 캘린더라 계산하지 않는다.)
    private func dayColor(grid: MonthCalendarGrid, day: Int, column: Int) -> Color {
        let weekday = grid.weekdayIndex(column: column)
        if weekday == 1 { return .red }
        if weekday == 7 { return fontColor.opacity(0.55) }
        return fontColor
    }

    /// 글자 크기 배율 — 위젯 `memoSizeScale`와 동일(small 0.7 / medium 0.85 / large 1.0).
    private var scale: CGFloat {
        switch textSize {
        case .small: 0.7
        case .medium: 0.85
        case .large: 1.0
        }
    }
}
