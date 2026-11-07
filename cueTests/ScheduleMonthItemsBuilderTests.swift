//
//  ScheduleMonthItemsBuilderTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 일정·할일 → 월 캘린더 칸별 항목. 범위는 2026년 11월 [11/1 00:00, 12/1 00:00).
struct ScheduleMonthItemsBuilderTests {

    /// 기기 시간대와 무관하게 결정적으로 돌도록 고정한 그레고리력.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func event(
        _ id: String, _ start: Date, _ end: Date,
        isAllDay: Bool = false, color: String? = "#FF0000", calendarID: String = "cal"
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: id, startDate: start, endDate: end,
            isAllDay: isAllDay, calendarColorHex: color, isReadOnly: false, calendarID: calendarID
        )
    }

    private func reminder(
        _ id: String, due: Date?, completed: Bool = false,
        includesTime: Bool = true, listID: String = "list"
    ) -> Reminder {
        Reminder(
            id: id, title: id, isCompleted: completed,
            notes: nil, dueDate: due, includesTime: includesTime, listID: listID
        )
    }

    private func build(
        events: [CalendarEvent] = [],
        reminders: [Reminder] = [],
        hiddenCalendarIDs: Set<String> = [],
        hiddenReminderListIDs: Set<String> = []
    ) -> [Date: [WidgetCalendarItem]] {
        ScheduleMonthItemsBuilder.itemsByDay(
            events: events,
            reminders: reminders,
            reminderListColorHexes: ["list": "#00FF00", "other": "#0000FF"],
            hiddenCalendarIDs: hiddenCalendarIDs,
            hiddenReminderListIDs: hiddenReminderListIDs,
            from: date(2026, 11, 1),
            to: date(2026, 12, 1),
            calendar: calendar
        )
    }

    /// 항목이 들어간 날들(키)의 일(day) 번호, 오름차순.
    private func days(_ result: [Date: [WidgetCalendarItem]]) -> [Int] {
        result.keys.sorted().map { calendar.component(.day, from: $0) }
    }

    // MARK: - 일정

    @Test func mapsAllDayAndTimedEvents() {
        let allDay = event("a", date(2026, 11, 3), date(2026, 11, 3, 23, 59, 59), isAllDay: true, color: "#123456")
        let timed = event("t", date(2026, 11, 3, 15), date(2026, 11, 3, 16))
        let items = build(events: [allDay, timed])[date(2026, 11, 3)] ?? []

        #expect(items.map(\.kind) == [.allDayEvent, .timedEvent])
        #expect(items.first?.colorHex == "#123456")
        #expect(items.first?.id == "a-\(date(2026, 11, 3).timeIntervalSince1970)")
        #expect(items.first?.isHighPriority == false)
    }

    @Test func keysAreMidnightOfEachDay() {
        // 15시 일정·9시 할일 모두 그날 자정 키로 묶인다 — 뷰가 startOfDay로 찾는다.
        let result = build(
            events: [event("t", date(2026, 11, 10, 15), date(2026, 11, 10, 16))],
            reminders: [reminder("r", due: date(2026, 11, 10, 9))]
        )
        #expect(Array(result.keys) == [date(2026, 11, 10)])
        #expect(result[date(2026, 11, 10)]?.count == 2)
    }

    @Test func multiDayAllDayEventCoversEveryDayInBothEndForms() {
        // EventKit 정규화(마지막 날 23:59:59)와 ICS 배타적 끝(다음 날 00:00)이 같은 답이어야 한다.
        let inclusive = build(events: [event("a", date(2026, 11, 3), date(2026, 11, 5, 23, 59, 59), isAllDay: true)])
        let exclusive = build(events: [event("a", date(2026, 11, 3), date(2026, 11, 6), isAllDay: true)])
        #expect(days(inclusive) == [3, 4, 5])
        #expect(days(exclusive) == [3, 4, 5])
    }

    @Test func midnightEndingTimedEventStaysOnStartDay() {
        #expect(days(build(events: [event("t", date(2026, 11, 7, 22), date(2026, 11, 8))])) == [7])
    }

    @Test func overnightTimedEventCoversBothDays() {
        #expect(days(build(events: [event("t", date(2026, 11, 7, 23), date(2026, 11, 8, 1))])) == [7, 8])
    }

    @Test func dropsDaysOutsideRange() {
        // 앞달에서 넘어오는 일정은 11월 날만, 다음 달로 넘어가는 일정도 11월 날만.
        let result = build(events: [
            event("prev", date(2026, 10, 30), date(2026, 11, 3), isAllDay: true),   // 10/30~11/2
            event("next", date(2026, 11, 30), date(2026, 12, 3), isAllDay: true),   // 11/30~12/2
        ])
        #expect(days(result) == [1, 2, 30])
    }

    // MARK: - 할일

    @Test func mapsReminderFields() {
        let due = date(2026, 11, 12, 9, 30)
        let result = build(reminders: [
            reminder("open", due: due),
            reminder("done", due: date(2026, 11, 12), completed: true, includesTime: false, listID: "other"),
        ])
        let items = result[date(2026, 11, 12)] ?? []

        let open = items.first { $0.reminderID == "open" }
        #expect(open?.kind == .reminder)
        #expect(open?.id == "open-\(due.timeIntervalSince1970)")
        #expect(open?.start == due && open?.end == due)
        #expect(open?.colorHex == "#00FF00")
        #expect(open?.hasTime == true)
        #expect(open?.isCompleted == false)

        let done = items.first { $0.reminderID == "done" }
        #expect(done?.colorHex == "#0000FF")
        #expect(done?.hasTime == false)
        #expect(done?.isCompleted == true)
    }

    @Test func excludesRemindersWithoutDueOrOutOfRange() {
        let result = build(reminders: [
            reminder("noDue", due: nil),
            reminder("before", due: date(2026, 10, 31, 23, 59)),
            reminder("after", due: date(2026, 12, 1)),   // to는 배타적
            reminder("in", due: date(2026, 11, 30, 23, 59)),
        ])
        #expect(result.values.flatMap { $0 }.compactMap(\.reminderID) == ["in"])
    }

    // MARK: - 숨김

    @Test func excludesHiddenCalendarsAndLists() {
        let result = build(
            events: [
                event("shown", date(2026, 11, 4, 9), date(2026, 11, 4, 10)),
                event("hidden", date(2026, 11, 4, 9), date(2026, 11, 4, 10), calendarID: "hiddenCal"),
            ],
            reminders: [
                reminder("shownR", due: date(2026, 11, 4, 9)),
                reminder("hiddenR", due: date(2026, 11, 4, 9), listID: "other"),
            ],
            hiddenCalendarIDs: ["hiddenCal"],
            hiddenReminderListIDs: ["other"]
        )
        #expect(result[date(2026, 11, 4)]?.map(\.title) == ["shown", "shownR"])
    }

    // MARK: - 정렬

    @Test func sortsAllDayThenTimedByStartThenOpenThenCompletedReminders() {
        let day = date(2026, 11, 20)
        let result = build(
            events: [
                event("late", date(2026, 11, 20, 14), date(2026, 11, 20, 15)),
                event("early", date(2026, 11, 20, 9), date(2026, 11, 20, 10)),
                event("allDay", day, date(2026, 11, 21), isAllDay: true),
            ],
            reminders: [
                // 완료 할일이 더 이른 시각이어도 미완료 뒤로 간다.
                reminder("done", due: date(2026, 11, 20, 7), completed: true),
                reminder("openB", due: date(2026, 11, 20, 8)),
                reminder("openA", due: date(2026, 11, 20, 8)),   // 같은 시각 → 제목순
            ]
        )
        #expect(result[day]?.map(\.title) == ["allDay", "early", "late", "openA", "openB", "done"])
    }
}
