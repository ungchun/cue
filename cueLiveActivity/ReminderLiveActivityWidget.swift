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
                ForEach(rows, id: \.first?.id) { row in
                    GridRow {
                        ForEach(row) { item in
                            ReminderItemCell(item: item)
                        }
                    }
                }
            }
        }
    }

    /// 위젯이 한 번에 보여주는 항목 수(2열 × 3행). ContentState엔 backfill용으로 더 실려 있고
    /// 여기서 앞 6개만 잘라 표시 — 체크로 하나 빠지면 다음 항목이 이 6칸을 자동으로 메운다.
    private static let displayLimit = 6

    /// 표시 항목을 2개씩 묶어 행 단위로 — 좌→우, 위→아래(읽기 순서).
    private var rows: [[LiveReminderItem]] {
        let shown = Array(state.items.prefix(Self.displayLimit))
        return stride(from: 0, to: shown.count, by: 2).map { start in
            Array(shown[start..<min(start + 2, shown.count)])
        }
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
