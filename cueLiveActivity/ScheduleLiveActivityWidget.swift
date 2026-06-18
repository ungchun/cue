//
//  ScheduleLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
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
                // 꾸욱 눌렀을 때 — 좌상단 월 · 우상단 "오늘 일정" 카운트 · 하단 이번 주 캘린더.
                DynamicIslandExpandedRegion(.leading) {
                    Text(WeekCalendarStrip.monthLabel(.now))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.sm)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // trailing은 같은 토큰도 leading보다 크게 렌더 — 한 단계 작은 caption2로 맞춤.
                    Text("일정 \(context.state.todayCount)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Spacing.sm)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WeekCalendarStrip(now: .now)
                }
            } compactLeading: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                DayProgressRing()
            } minimal: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.tint)
            }
        }
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

    /// 게시 시점에 그 날 기준으로 계산해 둔 시간 문구(진행 중 / → 종료 / 시작 → 등).
    private var timeText: String { event.timeText }

    /// 캘린더 색(외부 데이터 hex). 없거나 파싱 실패면 시스템 accent.
    private var color: Color {
        guard let hex = event.calendarColorHex, let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }
}
