//
//  ScheduleLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

/// 일정 라이브 액티비티 위젯 — **placeholder UI**. 본격 디자인(좌측 오늘/우측 내일 2열,
/// rail 디자인, dynamic island next-event 카운트다운)은 다음 사이클에서.
struct ScheduleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleLiveActivityAttributes.self) { context in
            HStack(alignment: .top, spacing: Spacing.md) {
                column(title: "오늘", events: context.state.today)
                Divider()
                column(title: "내일", events: context.state.tomorrow)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let next = nextEvent(context: context) {
                        Text(next.startDate, style: .relative)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let next = nextEvent(context: context) {
                        Text(next.title)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("일정 없음")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("오늘 \(context.state.today.count) · 내일 \(context.state.tomorrow.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                if let next = nextEvent(context: context) {
                    Text(next.startDate, style: .relative)
                        .monospacedDigit()
                        .frame(maxWidth: 60)
                }
            } minimal: {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            }
        }
    }

    /// 한 컬럼(오늘 또는 내일) — 라벨 + 이벤트 최대 3개. 시간이 표시는 시스템 위임으로 자동 갱신.
    @ViewBuilder
    private func column(title: String, events: [LiveEventItem]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(events.prefix(3)) { event in
                VStack(alignment: .leading, spacing: 0) {
                    Text(event.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if events.isEmpty {
                Text("—")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 오늘부터 가장 가까운 다음 이벤트 — Dynamic Island center/trailing 표시용.
    private func nextEvent(context: ActivityViewContext<ScheduleLiveActivityAttributes>) -> LiveEventItem? {
        context.state.today.first ?? context.state.tomorrow.first
    }
}
