//
//  CalendarWidgetProvider.swift
//  cueLiveActivity
//
//  홈 화면 캘린더 위젯 4종의 타임라인 공급.
//
//  위젯은 상태를 들고 있을 수 없으므로 매 렌더마다 (1) App Group에서 이동 오프셋을 읽고
//  (2) 그 구간의 일정·미리알림을 EventKit에서 그 자리에서 조회한다. 셰브런 탭은 오프셋만
//  바꾸고 WidgetKit이 타임라인을 다시 요청하게 둔다.
//

import EventKit
import SwiftUI
import WidgetKit

struct CalendarWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetCalendarSnapshot
    /// 표시 구간 이동량 — 월 위젯은 개월, 1일·3일 위젯은 일. 고정형은 항상 0.
    let offset: Int
}

/// 위젯이 어떤 구간을 그리는지 — 프로바이더가 조회 범위와 갱신 주기를 이 값으로 정한다.
enum CalendarWidgetRange {
    /// 한 달. `kind`가 `nil`이면 오늘 기준 고정(셰브런 없음).
    case month(shift: WidgetRangeKind?)
    /// 오늘부터 `days`일. 항상 이동 가능.
    case days(count: Int, shift: WidgetRangeKind)

    var shiftKind: WidgetRangeKind? {
        switch self {
        case .month(let shift): return shift
        case .days(_, let shift): return shift
        }
    }
}

struct CalendarWidgetProvider: TimelineProvider {
    let range: CalendarWidgetRange

    func placeholder(in context: Context) -> CalendarWidgetEntry {
        CalendarWidgetEntry(date: Date(), snapshot: .empty, offset: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        // 갤러리 미리보기는 권한 프롬프트도, EventKit 조회도 하지 않는다 — 빈 격자만.
        guard !context.isPreview else { return completion(placeholder(in: context)) }
        load { completion($0) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        load { entry in
            completion(Timeline(entries: [entry], policy: .after(nextRefresh(after: entry.date))))
        }
    }

    // MARK: - 조회

    /// EventKit 조회는 미리알림 콜백을 세마포어로 기다리므로 **메인 스레드를 피해** 돌린다.
    private func load(_ completion: @escaping (CalendarWidgetEntry) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let now = Date()
            let calendar = Calendar.current
            let offset = currentOffset(now: now, calendar: calendar)
            let bounds = self.bounds(now: now, offset: offset, calendar: calendar)
            let snapshot = WidgetCalendarDataSource.snapshot(
                from: bounds.start, to: bounds.end, calendar: calendar
            )
            completion(CalendarWidgetEntry(date: now, snapshot: snapshot, offset: offset))
        }
    }

    private func currentOffset(now: Date, calendar: Calendar) -> Int {
        guard let kind = range.shiftKind else { return 0 }
        return WidgetRangeOffsetStore.shared.offset(for: kind, now: now, calendar: calendar)
    }

    /// 조회 구간 — 화면에 그리는 날들만. 월은 그 달 전체, 일 위젯은 표시하는 날 수만큼.
    private func bounds(now: Date, offset: Int, calendar: Calendar) -> (start: Date, end: Date) {
        switch range {
        case .month:
            let base = calendar.startOfDay(for: now)
            let shifted = calendar.date(byAdding: .month, value: offset, to: base) ?? base
            let month = calendar.dateInterval(of: .month, for: shifted)
            return (month?.start ?? base, month?.end ?? base)
        case .days(let count, _):
            let start = CalendarWidgetProvider.firstDay(now: now, offset: offset, calendar: calendar)
            let end = calendar.date(byAdding: .day, value: count, to: start) ?? start
            return (start, end)
        }
    }

    /// 1일·3일 위젯이 그리는 첫 날 — 오늘에서 오프셋(일)만큼 민 날의 자정.
    static func firstDay(now: Date, offset: Int, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    // MARK: - 갱신 주기

    /// 다음 갱신 시각.
    ///
    /// 월 위젯은 날짜가 바뀔 때(자정)만 그림이 달라지므로 자정 한 번이면 충분하다.
    /// 시간표 위젯은 그보다 자주 — 다만 매 분 갱신은 위젯 예산을 태우기만 하므로 정시마다.
    /// 어느 쪽이든 EventKit 변경은 앱이 `WidgetCenter.reloadAllTimelines()`로 밀어준다.
    private func nextRefresh(after date: Date) -> Date {
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(3600)
        switch range {
        case .month:
            return midnight
        case .days:
            let nextHour = calendar.nextDate(
                after: date, matching: DateComponents(minute: 0), matchingPolicy: .nextTime
            ) ?? date.addingTimeInterval(3600)
            return min(nextHour, midnight)
        }
    }
}

// MARK: - 권한 안내

/// 캘린더·미리알림 접근이 없을 때 빈 격자 대신 띄우는 안내.
struct WidgetAccessPrompt: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Open Cue to allow Calendar access")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
