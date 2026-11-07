//
//  ScheduleMonthItemsBuilder.swift
//  cue / Domain
//

import Foundation

/// 월 캘린더 칸에 그릴 일정·할일을 날짜(자정)별 `WidgetCalendarItem` 목록으로 만든다.
///
/// 위젯(`WidgetCalendarDataSource`)과 같은 표시 DTO·같은 걸침 규칙(`DaySpan`)을 쓴다 —
/// 갈리면 같은 일정이 앱 월 캘린더와 위젯에서 다른 날짜에 걸린다.
/// 위젯과 달리 완료 할일은 기간과 무관하게 항상 보여준다(지난 달을 넘겨 봐도 한 일이 남게).
enum ScheduleMonthItemsBuilder {

    static func itemsByDay(
        events: [CalendarEvent],
        reminders: [Reminder],
        reminderListColorHexes: [String: String],
        hiddenCalendarIDs: Set<String>,
        hiddenReminderListIDs: Set<String>,
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> [Date: [WidgetCalendarItem]] {
        let lowerBound = calendar.startOfDay(for: from)
        var result: [Date: [WidgetCalendarItem]] = [:]

        for event in events where !hiddenCalendarIDs.contains(event.calendarID) {
            let item = WidgetCalendarItem(
                // 반복 일정은 같은 id를 공유하므로 시작 시각으로 회차를 구분한다(ForEach id 충돌 방지).
                id: "\(event.id)-\(event.startDate.timeIntervalSince1970)",
                title: event.title,
                start: event.startDate,
                end: event.endDate,
                kind: event.isAllDay ? .allDayEvent : .timedEvent,
                colorHex: event.calendarColorHex,
                isHighPriority: false,
                eventID: event.id
            )
            // 걸치는 날마다 복제하되, 앞·뒷달로 넘친 날은 이 범위의 칸이 아니라 버린다.
            // 복제본의 start는 그날로 자르지 않은 회차 시작 그대로 — 칩 탭이 이 회차를 연다.
            for day in DaySpan.days(from: item.start, to: item.end, calendar: calendar)
            where day >= lowerBound && day < to {
                result[day, default: []].append(item)
            }
        }

        for reminder in reminders where !hiddenReminderListIDs.contains(reminder.listID) {
            guard let due = reminder.dueDate, due >= from, due < to else { continue }
            let item = WidgetCalendarItem(
                // 반복 할일도 회차마다 같은 id라 마감 시각을 붙인다.
                id: "\(reminder.id)-\(due.timeIntervalSince1970)",
                title: reminder.title,
                start: due,
                end: due,
                kind: .reminder,
                colorHex: reminderListColorHexes[reminder.listID],
                isHighPriority: false,
                hasTime: reminder.includesTime,
                reminderID: reminder.id,
                isCompleted: reminder.isCompleted
            )
            result[calendar.startOfDay(for: due), default: []].append(item)
        }

        return result.mapValues(sorted)
    }

    /// 칸 안 순서 — 종일 → 시간 일정 → 미완료 할일 → 완료 할일, 같은 그룹은 시작 → 제목 → id.
    ///
    /// `MonthWidgetPacker.sorted`는 완료 여부를 가르지 않아(위젯은 지난 완료분을 이미 걸러낸다)
    /// 여기서 직접 비교한다. 제목·id까지 보는 건 같은 시각 항목이 재적재마다 뒤집히지 않게 하려는 것.
    private static func sorted(_ items: [WidgetCalendarItem]) -> [WidgetCalendarItem] {
        items.sorted { lhs, rhs in
            let lhsRank = rank(lhs), rhsRank = rank(rhs)
            if lhsRank != rhsRank { return lhsRank < rhsRank }
            if lhs.start != rhs.start { return lhs.start < rhs.start }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id < rhs.id
        }
    }

    private static func rank(_ item: WidgetCalendarItem) -> Int {
        switch item.kind {
        case .allDayEvent: 0
        case .timedEvent: 1
        case .reminder: item.isCompleted ? 3 : 2
        }
    }
}
