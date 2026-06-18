//
//  StartScheduleLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 일정 스냅샷을 라이브 액티비티로 게시.
///
/// 평탄한 이벤트 목록을 **날짜별로 묶고**(오늘부터), 각 날에 라벨(오늘/내일/모레 또는
/// `"4/10 (수)"`)을 붙여 `LiveScheduleDay` 배열로 만든다. 종일 이벤트는 그날 위로 정렬한다.
/// 실제로 2열에 몇 개를 보일지는 위젯이 정하지만, **ActivityKit ContentState ~4KB 한도** 때문에
/// `maxTotalEvents`로 싣는 총 이벤트 수를 제한한다(초과 시 throw로 LA가 아예 안 뜬다).
/// `now`는 라벨 계산 기준 — 테스트에서 주입한다.
struct StartScheduleLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    static let maxDays = 5
    /// 하루에 싣는 최대 이벤트 수. 실제 표시량은 `SchedulePacker`가 160pt 높이로 자르므로,
    /// 이 값은 "한 날이 2열을 꽉 채울 만큼"만 넉넉히 두면 된다(높이가 진짜 한계가 되게).
    static let maxEventsPerDay = 10
    /// ContentState에 싣는 총 이벤트 상한 — 4KB 한도 안전 마진. 위젯이 보여줄 수 있는 양보다
    /// 약간 넉넉. 이 수를 채우면 이후 날/이벤트는 버린다.
    static let maxTotalEvents = 14

    /// 게시했으면 `true`, 보여줄 (다가오는) 일정이 없어 건너뛰었으면 `false`.
    @discardableResult
    func callAsFunction(events: [CalendarEvent], now: Date = .now) async throws -> Bool {
        let days = Self.groupIntoDays(events, now: now)
        guard !days.isEmpty else { return false }   // 다가오는 일정 없으면 LA 안 띄움
        try await service.startSchedule(days: days, todayCount: Self.todayEventCount(events, now: now))
        return true
    }

    /// Dynamic Island 주간 캘린더 스트립의 "오늘 일정" 카운트.
    /// 포함: 오늘 종일 전부 + 오늘 시간 이벤트 중 아직 종료 안 된 것(endDate > now). 다른 날 제외.
    static func todayEventCount(_ events: [CalendarEvent], now: Date) -> Int {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        return events.filter { event in
            guard calendar.isDate(event.startDate, inSameDayAs: todayStart) else { return false }
            return event.isAllDay || event.endDate > now
        }.count
    }

    static func groupIntoDays(_ events: [CalendarEvent], now: Date) -> [LiveScheduleDay] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        // 오늘까지 걸치는 일정만 — 인앱 화면과 동일 기준:
        // 1) `endDate > todayStart` : 어제 안에서 끝난 일정은 제외(오늘로 안 넘어옴).
        // 2) 시간 이벤트는 `endDate >= now` 로 이미 끝난 건 숨김(종일은 시간 무관 유지).
        // 오늘 이전 '시작'이라도 오늘까지 진행 중이면 포함 — 아래 grouping에서 오늘로 끌어올린다.
        let upcoming = events.filter { event in
            event.endDate > todayStart
                && (event.isAllDay || event.endDate >= now)
        }
        // 시작일이 오늘 이전이면 오늘 그룹으로 끌어올림(멀티데이가 지난 날짜 헤더 대신 오늘에 묶이게).
        let grouped = Dictionary(grouping: upcoming) {
            max(calendar.startOfDay(for: $0.startDate), todayStart)
        }

        var remaining = maxTotalEvents
        var days: [LiveScheduleDay] = []
        for dayStart in grouped.keys.sorted().prefix(maxDays) {
            if remaining <= 0 { break }
            let dayEvents = (grouped[dayStart] ?? [])
                .sorted { $0.startDate < $1.startDate }   // 인앱(ScheduleViewModel)과 동일 — 순수 시작시간순
                .prefix(min(maxEventsPerDay, remaining))
                .map { map($0, dayStart: dayStart) }
            if dayEvents.isEmpty { continue }
            remaining -= dayEvents.count
            days.append(LiveScheduleDay(
                id: ISO8601DateFormatter().string(from: dayStart),
                label: label(for: dayStart, now: now, calendar: calendar),
                events: Array(dayEvents)
            ))
        }
        return days
    }

    /// 날짜 라벨 — 0/1/2일 차는 오늘/내일/모레, 그 뒤는 `"M/d (요일)"`.
    private static func label(for dayStart: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        let offset = calendar.dateComponents([.day], from: today, to: dayStart).day ?? 0
        switch offset {
        case 0: return "오늘"
        case 1: return "내일"
        case 2: return "모레"
        default: return dateLabelFormatter.string(from: dayStart)
        }
    }

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d (E)"
        return formatter
    }()

    /// 표시용 매핑 — id/title/시각/캘린더 색/종일 여부 + 그 날(dayStart) 기준 시간 문구.
    private static func map(_ event: CalendarEvent, dayStart: Date) -> LiveEventItem {
        LiveEventItem(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            timeText: ScheduleTimeText.string(
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                groupDate: dayStart
            ),
            calendarColorHex: event.calendarColorHex,
            isAllDay: event.isAllDay
        )
    }
}
