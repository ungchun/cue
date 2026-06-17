//
//  ScheduleLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

/// 일정 라이브 액티비티 위젯.
///
/// 잠금화면: 날짜 묶음(오늘/내일/모레/`"4/10 (수)"`)을 2열에 통째로 채워 **들어가는 만큼만**
/// 그린다. 종일 이벤트는 색 캡슐(제목만), 시간 이벤트는 좌측 색 막대 + 제목 + 시간(시작—끝).
struct ScheduleLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ScheduleLiveActivityAttributes.self) { context in
            ScheduleLockScreenView(days: context.state.days)
                .padding(ScheduleMetrics.outerPadding)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 상대시간은 다음 '시간' 이벤트만 — 종일은 startDate가 자정이라 "N시간 전"으로 잘못 표시됨.
                    if let next = nextTimedEvent(context.state.days) {
                        Text(next.startDate, style: .relative)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if let first = firstEvent(context.state.days) {
                        Text(first.title)
                            .font(.headline)
                            .lineLimit(1)
                    } else {
                        Text("일정 없음")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("일정 \(eventCount(context.state.days))개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "calendar")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                if let next = nextTimedEvent(context.state.days) {
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

    /// 다음 '시간' 이벤트(종일 제외) — 상대시간 표시용.
    private func nextTimedEvent(_ days: [LiveScheduleDay]) -> LiveEventItem? {
        days.flatMap(\.events).first { !$0.isAllDay }
    }

    /// 첫 이벤트(종일 포함) — 센터 제목용.
    private func firstEvent(_ days: [LiveScheduleDay]) -> LiveEventItem? {
        days.flatMap(\.events).first
    }

    private func eventCount(_ days: [LiveScheduleDay]) -> Int {
        days.reduce(0) { $0 + $1.events.count }
    }
}

/// 잠금화면 본문 — day 묶음을 2열에 **실제 높이 기준**으로 채운다.
private struct ScheduleLockScreenView: View {
    let days: [LiveScheduleDay]

    var body: some View {
        let columns = SchedulePacker.pack(days)
        // 상단 정렬, 가운데 세로 디바이더는 항상 표시(왼쪽에만 일정이 있어도). 예정 일정이 없을 땐
        // 애초에 LA를 게시하지 않으므로(use case에서 skip) 빈 양쪽 케이스는 사실상 오지 않는다.
        HStack(alignment: .top, spacing: ScheduleMetrics.columnGap) {
            column(columns.left)
            Divider()
            column(columns.right)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func column(_ chunks: [DayChunk]) -> some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.dayGap) {
            ForEach(chunks) { chunk in
                ScheduleDayView(chunk: chunk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// 한 열의 한 묶음 — (있으면) 날짜 헤더 + 이벤트들. 연속 묶음은 헤더 없이 이벤트만.
private struct ScheduleDayView: View {
    let chunk: DayChunk

    var body: some View {
        VStack(alignment: .leading, spacing: ScheduleMetrics.rowGap) {
            if let label = chunk.label {
                Text(label)
                    .font(.caption.weight(.semibold))
                    // "오늘"만 강조, 그 외 날짜는 옅게.
                    .foregroundStyle(label == "오늘" ? Color.primary : Color.secondary)
            }
            ForEach(chunk.events) { event in
                ScheduleEventRow(event: event)
            }
        }
    }
}

/// 이벤트 한 줄 — 종일은 색 캡슐, 시간 이벤트는 좌측 색 막대 + 제목 + 시간.
private struct ScheduleEventRow: View {
    let event: LiveEventItem

    var body: some View {
        if event.isAllDay {
            Text(event.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Capsule().fill(color.opacity(0.18)))
        } else {
            HStack(alignment: .center, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: Spacing.xxs)
                    .fill(color)
                    .frame(width: Spacing.xs)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(event.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                    Text(timeText)
                        .font(.caption2)
                        .foregroundStyle(color)
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var timeText: String {
        let f = Self.timeFormatter
        return "\(f.string(from: event.startDate)) — \(f.string(from: event.endDate))"
    }

    /// 캘린더 색(외부 데이터 hex). 없거나 파싱 실패면 시스템 accent.
    private var color: Color {
        guard let hex = event.calendarColorHex, let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}
