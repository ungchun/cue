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
                // 상하는 일정 LA와 같은 `outerPadding`(12) — 캘린더 예산(columnMax)이
                // "160 − 상하 패딩×2"로 잡혀 있어, 상하를 16으로 주면 합이 168pt가 되어
                // 시스템이 하단 8pt를 잘랐다(목록 마지막 줄과 6주 달 점이 밀림).
                .padding(.vertical, ScheduleMetrics.outerPadding)
                .padding(.horizontal, Spacing.md)
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
        // "할일 + 캘린더"면 왼쪽 반을 월간 캘린더로, 할일은 오른쪽 1열로.
        if showsCalendar() {
            HStack(alignment: .top, spacing: Spacing.md) {
                MonthCalendarView(
                    grid: MonthCalendarGrid(now: .now, monthOffset: state.calendarMonthOffset),
                    intentTarget: ShiftCalendarMonthIntent.reminderTarget,
                    eventDots: state.monthEventDots,
                    holidays: state.monthHolidays,
                    // 목업(예시) 캘린더는 정적 — 월 이동 셰브런을 숨긴다.
                    allowsMonthShift: !state.isSample
                )
                .frame(maxWidth: .infinity)
                // 달력 높이를 예산으로 클램프 — 일정·메모 LA와 같은 이유(6주 달의 자연
                // 높이가 fixedSize를 타고 예산을 밀어올리는 것을 막는다).
                .frame(height: ScheduleMetrics.columnMax)
                // 캘린더와 목록 사이 세로 디바이더 — 일정 LA와 동일.
                Divider()
                // 캘린더 모드는 1열 세로 나열이라 많으면 LA 높이를 넘는다 — 카운터가
                // 우상단에 있으므로 3개(4개면 첫 행이 카운터와 겹친다).
                calendarModeList(limit: 3)
                    .frame(maxWidth: .infinity)
            }
            // 캘린더 모드에선 카드를 LA 최대 높이까지 늘려 캘린더를 최대 크기로 그린다(일정과 동일).
            .frame(minHeight: ScheduleMetrics.columnMax, alignment: .top)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            content(columns: 2, limit: Self.displayLimit)
        }
    }

    /// 캘린더 모드의 오른쪽 1열 — 카운터를 첫 줄로 쌓고, 그 아래 행들이 남는 높이를
    /// 고르게 나눠 앉는다.
    private func calendarModeList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.zero) {
            HStack {
                Spacer(minLength: Spacing.zero)
                Text("\(ReminderDynamicIsland.incompleteCount(state))")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            // 카운터 줄 상자를 아래로 살짝 좁혀 첫 행을 숫자 쪽으로 끌어올린다.
            .padding(.bottom, -Spacing.xs)

            ForEach(state.items.prefix(limit)) { item in
                ReminderItemCell(item: item)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 카운트 + 체크리스트 — 캘린더 없는 2열 모드 전용(캘린더 모드는 `calendarModeList`).
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
            // 카운터 줄 상자를 아래로 살짝 좁혀 목록을 숫자 쪽으로 끌어올린다(캘린더 모드와 같은 값).
            .padding(.bottom, -Spacing.xs)

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

    /// 표시 결정은 게시 시점에 앱이 정해 ContentState로 실어 보낸다 — 미러 읽기는 결정이
    /// 없던 **옛 활성 LA**의 폴백일 뿐이다(렌더 시점 미러 읽기가 "설정 ON인데 캘린더 없음"의
    /// 원인이었고, 위젯 프로세스에선 검증도 복구도 불가능했다).
    private func showsCalendar() -> Bool {
        state.showsCalendar
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
