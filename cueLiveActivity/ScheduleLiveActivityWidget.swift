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
            ScheduleLockScreenView(
                days: context.state.days,
                calendarMonthOffset: context.state.calendarMonthOffset,
                monthEventDots: context.state.monthEventDots
            )
            .padding(.vertical, ScheduleMetrics.outerPadding)
            .padding(.horizontal, ScheduleMetrics.outerHorizontalPadding)
            // iOS 26 잠금화면 LA는 표준(.large) 타입 램프 자체가 커져(caption1 줄높이
            // 실측 16.3 vs 이전 14.3) 예산 136pt에 행이 몇 개 못 들어간다. 레퍼런스급
            // 밀도(~11pt 렌더)를 위해 타입 스케일을 xSmall로 고정 — 패커 줄높이 추정도
            // 같은 카테고리로 고정해(ScheduleMetrics) 추정=렌더를 유지한다.
            .dynamicTypeSize(.xSmall)
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
                    Text("Events \(context.state.todayCount)")
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

/// 잠금화면 본문 — day 묶음을 2열에 **실제 높이 기준**으로 채운다.
/// 설정 "일정 + 캘린더"(App Group 미러)면 왼쪽 반을 월간 캘린더로, 일정은 오른쪽 1열로.
private struct ScheduleLockScreenView: View {
    let days: [LiveScheduleDay]
    let calendarMonthOffset: Int
    var monthEventDots: [LiveMonthDot] = []

    /// 설정 미러 — 위젯은 렌더 시점에 읽는다(상태 갱신 시 재렌더).
    private var showsCalendar: Bool {
        SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.scheduleShowsCalendar)
    }

    var body: some View {
        // 상단 정렬, 가운데 세로 디바이더는 항상 표시(왼쪽에만 일정이 있어도). 예정 일정이 없을 땐
        // 애초에 LA를 게시하지 않으므로(use case에서 skip) 빈 양쪽 케이스는 사실상 오지 않는다.
        HStack(alignment: .top, spacing: ScheduleMetrics.columnGap) {
            if showsCalendar {
                MonthCalendarView(
                    grid: MonthCalendarGrid(now: .now, monthOffset: calendarMonthOffset),
                    intentTarget: ShiftCalendarMonthIntent.scheduleTarget,
                    eventDots: monthEventDots
                )
                .frame(maxWidth: .infinity)
                // 달력 높이를 예산으로 **클램프** — 아래 `.fixedSize(vertical:)`는 자식의 자연
                // 높이를 그대로 취하므로, 6주 달(자연 높이 157pt+)이 상한 없이 전체를 예산
                // (columnMax) 위로 밀어올려 시스템이 하단을 잘라냈다(31일 줄 잘림). 고정 높이를
                // 주면 주 행들의 maxHeight .infinity가 유계 공간 분배로 동작해 6주 달은 행이
                // 살짝 조밀해질 뿐 총높이 ≤ 160pt가 보장된다.
                .frame(height: ScheduleMetrics.columnMax)
                Divider()
                column(SchedulePacker.packSingleColumn(days))
            } else {
                let columns = SchedulePacker.pack(days)
                column(columns.left)
                Divider()
                column(columns.right)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // 캘린더 모드에선 일정이 적어도 카드를 LA 최대 높이까지 늘려 캘린더를 최대 크기로 그린다.
        .frame(minHeight: showsCalendar ? ScheduleMetrics.columnMax : nil, alignment: .top)
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
        // 행 간격은 종류 조합별로 달라(캡슐 인접 4·시간끼리 2) 단일 spacing
        // 대신 행마다 상단 패딩으로 준다 — 패커의 headerGap/rowGap(previous:next:)와 동기.
        VStack(alignment: .leading, spacing: Spacing.zero) {
            if let label = chunk.label {
                Text(label)
                    // 헤더를 이벤트 제목보다 한 단계 작게 — 패커의 header 추정(caption2)과 동기.
                    .font(.caption2.weight(.semibold))
                    // 오늘만 강조, 그 외 날짜는 옅게. 앱이 심은 라벨과 같은 로케일 키로 비교.
                    .foregroundStyle(label == String(localized: "Today") ? Color.primary : Color.secondary)
            }
            ForEach(Array(chunk.events.enumerated()), id: \.element.id) { index, event in
                ScheduleEventRow(event: event)
                    .padding(.top, topGap(at: index))
            }
        }
    }

    /// 행별 상단 간격 — 첫 행은 헤더가 있으면 headerGap, 없으면(연속 청크) 0.
    /// 이후 행은 이전 행 종류에 따라 rowGap(previous:next:).
    private func topGap(at index: Int) -> CGFloat {
        if index == 0 {
            return chunk.label != nil ? ScheduleMetrics.headerGap : Spacing.zero
        }
        return ScheduleMetrics.rowGap(previous: chunk.events[index - 1], next: chunk.events[index])
    }
}

/// 이벤트 한 줄 — 종일은 색 캡슐, 시간 이벤트는 좌측 색 막대 + 제목 + 시간.
private struct ScheduleEventRow: View {
    let event: LiveEventItem

    var body: some View {
        if event.isAllDay {
            Text(event.title)
                // 이벤트 텍스트는 고정 12pt(디자인 결정) — 패커 eventFontSize와 동기.
                .font(.system(size: ScheduleMetrics.eventFontSize, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .padding(.horizontal, Spacing.sm)
                // 세로 패딩만 얇게(2) — 패커 eventHeight(allDay)와 동기.
                .padding(.vertical, Spacing.xxs)
                // 캡슐이 컬럼 가로를 꽉 채우고 텍스트는 가운데 정렬.
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(color.opacity(0.18)))
        } else {
            HStack(alignment: .center, spacing: Spacing.xs) {
                // 굵기 2.5는 토큰 밖 의도값 — 2는 얇고 3부터는 둔탁해 중간을 쓴다(디자인 결정).
                RoundedRectangle(cornerRadius: 1.25)
                    .fill(color)
                    .frame(width: 2.5)
                    .frame(maxHeight: .infinity)
                    // 줄박스에는 글자 위아래 투명 여백(리딩)이 포함돼 막대가 글자보다
                    // 길어 보인다 — 위아래를 인셋해 보이는 글자 높이에 맞춘다.
                    .padding(.vertical, Spacing.xxs)
                VStack(alignment: .leading, spacing: Spacing.zero) {
                    Text(event.title)
                        // 고정 12pt(디자인 결정) — 굵기 semibold로 시간과 위계 구분.
                        .font(.system(size: ScheduleMetrics.eventFontSize, weight: .semibold))
                        .lineLimit(1)
                    Text(timeText)
                        .font(.system(size: ScheduleMetrics.eventFontSize))
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
