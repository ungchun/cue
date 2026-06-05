//
//  ReminderLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

/// 미리알림 라이브 액티비티 위젯 — **placeholder UI**. 본격 디자인(체크리스트 row,
/// dynamic island count badge)은 다음 사이클에서.
struct ReminderLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderLiveActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(context.attributes.listTitle)
                    .font(.headline)
                ForEach(context.state.items.prefix(3)) { item in
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                        Text(item.title)
                            .lineLimit(1)
                    }
                    .font(.callout)
                }
                if context.state.remaining > 0 {
                    Text("+\(context.state.remaining)개 더")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "checklist")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.items.count + context.state.remaining)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.listTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let first = context.state.items.first {
                        Text(first.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            } compactLeading: {
                Image(systemName: "checklist")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                Text("\(context.state.items.count + context.state.remaining)")
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "checklist")
                    .foregroundStyle(.tint)
            }
        }
    }
}
