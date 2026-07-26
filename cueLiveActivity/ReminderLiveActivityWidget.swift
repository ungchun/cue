//
//  ReminderLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 미리알림 라이브 액티비티 위젯.
///
/// 잠금화면 레이아웃: **좌상단 비움 · 우상단 미완료 카운트 · 본문 2열 체크리스트**.
/// 각 항목 동그라미는 자기 미리알림 리스트 색(`colorHex`)으로, 없으면 시스템 색 폴백.
struct ReminderLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            ReminderLockScreenView(state: context.state)
                .padding(Spacing.md)
                // 시스템 글래스(블러) 재질 배경 — 일정 LA와 동일한 반투명 카드 톤(전 LA 통일).
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                // 꾸욱 눌렀을 때 — 좌상단 월 · 우상단 "오늘 할일" 카운트 · 하단 이번 주 캘린더.
                DynamicIslandExpandedRegion(.leading) {
                    Text(WeekCalendarStrip.monthLabel(.now))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.sm)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // trailing은 같은 토큰도 leading보다 크게 렌더 — 한 단계 작은 caption2로 맞춤.
                    Text("Tasks \(context.state.todayCount)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Spacing.sm)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WeekCalendarStrip(now: .now, eventDots: context.state.weekEventDots)
                }
            } compactLeading: {
                AppIconMarkView()
            } compactTrailing: {
                DayProgressRing()
            } minimal: {
                AppIconMarkView()
            }
        }
    }
}

/// 잠금화면 본문. 우상단 카운트 + 2열 체크리스트.
private struct ReminderLockScreenView: View {
    let state: ReminderLiveActivityAttributes.ContentState

    var body: some View {
        // 설정 "할일 + 캘린더"(App Group 미러)면 왼쪽 반을 월간 캘린더로, 할일은 오른쪽 1열로.
        if showsCalendar() {
            HStack(alignment: .top, spacing: Spacing.md) {
                MonthCalendarView(
                    grid: MonthCalendarGrid(now: .now, monthOffset: state.calendarMonthOffset),
                    intentTarget: ShiftCalendarMonthIntent.reminderTarget,
                    eventDots: state.monthEventDots,
                    // 목업(오버라이드) 캘린더는 정적 — 월 이동 셰브런을 숨긴다.
                    allowsMonthShift: state.showsCalendarOverride == nil
                )
                .frame(maxWidth: .infinity)
                // 캘린더 모드는 1열 세로 나열이라 많으면 LA 높이를 넘는다 — 3개로 제한.
                content(columns: 1, limit: 3)
                    .frame(maxWidth: .infinity)
            }
            // 캘린더 모드에선 카드를 LA 최대 높이까지 늘려 캘린더를 최대 크기로 그린다(일정과 동일).
            .frame(minHeight: ScheduleMetrics.columnMax, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            content(columns: 2, limit: Self.displayLimit)
        }
    }

    /// 카운트 + 체크리스트. `columns`는 열 수(2열 기본, 캘린더 모드 1열), `limit`은 표시 개수.
    private func content(columns: Int, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // 좌상단은 비움, 우상단에 미완료 카운트.
            HStack {
                Spacer(minLength: Spacing.zero)
                Text("\(ReminderDynamicIsland.incompleteCount(state))")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: Spacing.smd) {
                ForEach(rows(columns: columns, limit: limit), id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { item in
                            ReminderItemCell(item: item)
                        }
                    }
                }
            }
        }
    }

    /// 기본(캘린더 없음) 표시 항목 수(2열 × 3행). ContentState엔 backfill용으로 더 실려 있고
    /// 여기서 앞부분만 잘라 표시 — 체크로 하나 빠지면 다음 항목이 자동으로 메운다.
    private static let displayLimit = 6

    /// 표시 항목을 앞 `limit`개만 잘라 `columns`개씩 묶어 행 단위로 — 좌→우, 위→아래(읽기 순서).
    private func rows(columns: Int, limit: Int) -> [[LiveReminderItem]] {
        let shown = Array(state.items.prefix(limit))
        return stride(from: 0, to: shown.count, by: columns).map { start in
            Array(shown[start..<min(start + columns, shown.count)])
        }
    }

    /// 설정 미러 — 위젯은 렌더 시점에 읽는다(상태 갱신 시 재렌더).
    /// ContentState 오버라이드(온보딩 목업)가 있으면 미러 대신 그 값을 따른다.
    private func showsCalendar() -> Bool {
        state.showsCalendarOverride
            ?? SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.reminderShowsCalendar)
    }
}

/// 체크리스트 한 칸 — 동그라미(리스트 색) + 제목.
private struct ReminderItemCell: View {
    let item: LiveReminderItem

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Button(intent: CompleteReminderIntent(reminderID: item.id)) {
                Circle()
                    .strokeBorder(circleColor, lineWidth: Spacing.xxs)
                    .frame(width: Spacing.lg, height: Spacing.lg)
            }
            .buttonStyle(.plain)
            Text(item.title)
                .font(.callout)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 리스트 색이 있으면 그 색, 없으면 시스템 보조색.
    private var circleColor: Color {
        guard let hex = item.colorHex, let color = Color(hex: hex) else { return .secondary }
        return color
    }
}
