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
    /// 유료 위젯을 잠글지. 갤러리 미리보기에서는 언제나 `false` —
    /// 무엇을 살지 고르는 자리에서 잠금을 보여주면 정작 위젯 모습을 알 수 없다.
    var isLocked: Bool = false
}

/// 위젯이 어떤 구간을 그리는지 — 프로바이더가 조회 범위와 갱신 주기를 이 값으로 정한다.
enum CalendarWidgetRange {
    /// 한 달. `kind`가 `nil`이면 오늘 기준 고정(셰브런 없음).
    case month(shift: WidgetRangeKind?)
    /// 오늘부터 `days`일. 항상 이동 가능.
    case days(count: Int, shift: WidgetRangeKind)
    /// 이번 달 격자 + 앞으로의 목록을 함께 그리는 위젯 — 이동하지 않는다.
    ///
    /// 조회 구간이 **이번 달과 앞으로 며칠의 합집합**이라 위 둘로 표현되지 않는다.
    /// 격자는 이번 달 전체가 필요하고, 옆 목록은 달을 넘겨 다음 달 초까지 이어질 수 있다.
    case upcoming

    var shiftKind: WidgetRangeKind? {
        switch self {
        case .month(let shift): return shift
        case .days(_, let shift): return shift
        case .upcoming: return nil
        }
    }
}

struct CalendarWidgetProvider: TimelineProvider {
    let range: CalendarWidgetRange
    /// 유료 위젯인지. `true`면 구독하지 않은 사용자에게 잠금이 덮인다.
    var requiresPremium = false

    /// 로딩 중 잠깐 비치는 자리표시자 — 조회를 기다릴 수 없으니 표본으로 채운다.
    /// 빈 격자를 두면 위젯이 깜빡이며 나타나는 것처럼 보인다.
    func placeholder(in context: Context) -> CalendarWidgetEntry {
        let now = Date()
        let calendar = Calendar.current
        let bounds = self.bounds(now: now, offset: 0, calendar: calendar)
        return CalendarWidgetEntry(
            date: now,
            snapshot: WidgetCalendarSample.snapshot(
                from: bounds.start, to: bounds.end, calendar: calendar
            ),
            offset: 0
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (CalendarWidgetEntry) -> Void) {
        guard context.isPreview else { return load { completion($0) } }
        // 갤러리 미리보기 — **권한이 있으면 진짜 일정**을 그린다. 자기 일정이 들어간 모습을
        // 봐야 이 위젯이 쓸모 있는지 판단할 수 있다.
        //
        // 권한이 없을 때만 표본으로 대체한다. 그때 EventKit을 조회하면 위젯을 고르다 말고
        // 권한 프롬프트를 만나고, 거절하면 빈 격자만 남아 무엇을 고르는지 알 수 없다.
        // 미리보기에서는 잠그지 않는다 — 무엇을 살지 고르는 자리에서 잠금을 보여주면
        // 정작 위젯 모습을 알 수 없다.
        load(preferSample: !WidgetCalendarDataSource.hasAnyAccess, locks: false) { completion($0) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalendarWidgetEntry>) -> Void) {
        load { entry in
            completion(Timeline(entries: [entry], policy: .after(nextRefresh(after: entry.date))))
        }
    }

    // MARK: - 조회

    /// EventKit 조회는 미리알림 콜백을 세마포어로 기다리므로 **메인 스레드를 피해** 돌린다.
    ///
    /// - Parameter preferSample: 실제 데이터 대신 표본을 채운다. 갤러리 미리보기에서
    ///   권한이 없을 때만 켠다 — 빈 격자보다 표본이 위젯을 고르는 데 도움이 된다.
    private func load(
        preferSample: Bool = false,
        locks: Bool = true,
        _ completion: @escaping (CalendarWidgetEntry) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let now = Date()
            let calendar = Calendar.current
            let offset = preferSample ? 0 : currentOffset(now: now, calendar: calendar)
            let bounds = self.bounds(now: now, offset: offset, calendar: calendar)
            let snapshot = preferSample
                ? WidgetCalendarSample.snapshot(
                    from: bounds.start, to: bounds.end, calendar: calendar
                )
                : WidgetCalendarDataSource.snapshot(
                    from: bounds.start, to: bounds.end, calendar: calendar
                )
            completion(
                CalendarWidgetEntry(
                    date: now,
                    snapshot: snapshot,
                    offset: offset,
                    // 앱이 App Group에 미러링한 확정 판정을 읽는다(→ `SharedAppGroup.isPremium`).
                    isLocked: locks && requiresPremium && !SharedAppGroup.isPremium
                )
            )
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
        case .upcoming:
            // 이번 달 **전체**(격자용)와 앞으로 며칠(목록용)의 합집합.
            //
            // 목록은 달을 넘어갈 수 있다 — 월말에 열면 이번 달엔 남은 게 없고 다음 달
            // 초의 일정이 올라와야 한다. 그때 구간을 이번 달로 끊으면 목록이 "없음"으로
            // 비는데, 실제로는 이틀 뒤에 일정이 있다.
            let base = calendar.startOfDay(for: now)
            let month = calendar.dateInterval(of: .month, for: base)
            let start = min(month?.start ?? base, base)
            let lookahead = calendar.date(byAdding: .day, value: Self.lookaheadDays, to: base) ?? base
            return (start, max(month?.end ?? lookahead, lookahead))
        }
    }

    /// 사이드 목록이 앞을 내다보는 날수.
    ///
    /// 목록은 오늘 것이 없으면 다음 날들로 채운다(→ `UpcomingItemPicker`). 너무 짧으면
    /// 한가한 주에 위젯이 비고, 너무 길면 조회 비용만 늘고 정작 "다음"이라 부르기 어려운
    /// 먼 일정이 올라온다. 2주면 네 줄을 채우기에 충분하다.
    private static let lookaheadDays = 14

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
        // 목록은 시각이 지나면 항목이 빠져야 하므로 시간표와 같은 주기로 본다 —
        // 자정까지 두면 이미 끝난 일정이 오후 내내 목록 맨 위에 남는다.
        case .days, .upcoming:
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
