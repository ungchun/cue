//
//  UpcomingItemPickerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 사이드 리스트 위젯이 "다음에 뭐가 있지"에 답하는 규칙.
///
/// 스냅샷은 날짜별 사전이라 그대로는 목록이 아니다 — 걸치는 일정이 날마다 복제돼 있고,
/// 정렬 기준도 없다. 그 사전을 시간순 목록으로 눕히는 과정에서 틀리기 쉬운 것들
/// (지난 항목, 중복, 종일 일정의 시각)을 화면 없이 못 박는다.
struct UpcomingItemPickerTests {

    private let calendar = Calendar(identifier: .gregorian)

    /// 2026-08-13 14:00 — 오늘 오후, 이미 지난 오전 일정이 있는 시각.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 13, hour: 14))!
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute)
        )!
    }

    private func item(
        id: String,
        _ kind: WidgetCalendarItem.Kind,
        start: Date,
        end: Date? = nil,
        isCompleted: Bool = false
    ) -> WidgetCalendarItem {
        WidgetCalendarItem(
            id: id,
            title: id,
            start: start,
            end: end ?? start,
            kind: kind,
            colorHex: nil,
            isHighPriority: false,
            isCompleted: isCompleted
        )
    }

    private func snapshot(_ items: [WidgetCalendarItem]) -> WidgetCalendarSnapshot {
        var byDay: [Date: [WidgetCalendarItem]] = [:]
        for item in items {
            byDay[calendar.startOfDay(for: item.start), default: []].append(item)
        }
        return WidgetCalendarSnapshot(itemsByDay: byDay, hasAccess: true)
    }

    /// 이미 끝난 항목은 빼고, 남은 것은 시간순으로 — 위젯의 기본 계약.
    @Test func keepsOnlyWhatIsStillAhead() {
        let past = item(id: "past", .timedEvent, start: date(day: 13, hour: 9), end: date(day: 13, hour: 10))
        let soon = item(id: "soon", .timedEvent, start: date(day: 13, hour: 19), end: date(day: 13, hour: 20))
        let later = item(id: "later", .timedEvent, start: date(day: 13, hour: 23), end: date(day: 13, hour: 23, minute: 30))

        let picked = UpcomingItemPicker.items(
            from: snapshot([past, soon, later]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["soon", "later"])
    }

    /// **진행 중**인 일정은 남는다 — 시작은 지났어도 아직 끝나지 않았으면 지금의 관심사다.
    @Test func keepsAnEventThatIsStillRunning() {
        let running = item(id: "running", .timedEvent, start: date(day: 13, hour: 13), end: date(day: 13, hour: 15))

        let picked = UpcomingItemPicker.items(
            from: snapshot([running]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["running"])
    }

    /// 오늘 것이 없으면 내일·모레 것으로 채운다 — 리스트가 비어 위젯이 텅 비지 않게.
    @Test func fallsForwardToLaterDaysWhenTodayIsEmpty() {
        let tomorrow = item(id: "tomorrow", .timedEvent, start: date(day: 14, hour: 9), end: date(day: 14, hour: 10))
        let dayAfter = item(id: "dayAfter", .timedEvent, start: date(day: 15, hour: 9), end: date(day: 15, hour: 10))

        let picked = UpcomingItemPicker.items(
            from: snapshot([tomorrow, dayAfter]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["tomorrow", "dayAfter"])
    }

    /// 오늘의 **종일** 일정은 오후에 열어도 남는다 — 시각이 자정이라 `start`로 재면
    /// 오전부터 이미 지난 것으로 취급돼 사라진다.
    @Test func todaysAllDayEventSurvivesTheAfternoon() {
        let allDay = item(
            id: "allDay",
            .allDayEvent,
            start: calendar.startOfDay(for: now),
            end: calendar.startOfDay(for: now)
        )

        let picked = UpcomingItemPicker.items(
            from: snapshot([allDay]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["allDay"])
    }

    /// 어제 시작한 종일 일정은 빼지 않는다 — 스냅샷이 걸치는 날마다 복제해 넣으므로
    /// 오늘 키에도 같은 항목이 들어 있고, 그건 여전히 오늘의 일정이다.
    @Test func multiDayAllDayEventCountsOnTodaysKey() {
        let started = calendar.startOfDay(for: date(day: 12, hour: 0))
        let ends = calendar.startOfDay(for: date(day: 15, hour: 0))
        // 스냅샷이 복제하듯 오늘 키에도 같은 id로 넣는다.
        var byDay: [Date: [WidgetCalendarItem]] = [:]
        let spanning = item(id: "spanning", .allDayEvent, start: started, end: ends)
        byDay[started] = [spanning]
        byDay[calendar.startOfDay(for: now)] = [spanning]

        let picked = UpcomingItemPicker.items(
            from: WidgetCalendarSnapshot(itemsByDay: byDay, hasAccess: true),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["spanning"])
    }

    /// 걸치는 일정이 날마다 복제돼 있어도 **한 번만** 나온다.
    @Test func doesNotRepeatASpanningEvent() {
        let spanning = item(id: "trip", .timedEvent, start: date(day: 13, hour: 18), end: date(day: 15, hour: 12))
        var byDay: [Date: [WidgetCalendarItem]] = [:]
        for day in 13...15 {
            byDay[calendar.startOfDay(for: date(day: day, hour: 0))] = [spanning]
        }

        let picked = UpcomingItemPicker.items(
            from: WidgetCalendarSnapshot(itemsByDay: byDay, hasAccess: true),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["trip"])
    }

    /// 종류로 가른다 — 일정 위젯에 할일이, 할일 위젯에 일정이 섞이면 안 된다.
    @Test func separatesEventsFromReminders() {
        let event = item(id: "event", .timedEvent, start: date(day: 13, hour: 19), end: date(day: 13, hour: 20))
        let allDay = item(id: "allDay", .allDayEvent, start: calendar.startOfDay(for: now))
        let todo = item(id: "todo", .reminder, start: date(day: 13, hour: 20))
        let source = snapshot([event, allDay, todo])

        let events = UpcomingItemPicker.items(
            from: source, kinds: [.timedEvent, .allDayEvent], now: now, limit: 4, calendar: calendar
        )
        let todos = UpcomingItemPicker.items(
            from: source, kinds: [.reminder], now: now, limit: 4, calendar: calendar
        )

        #expect(Set(events.map(\.id)) == ["event", "allDay"])
        #expect(todos.map(\.id) == ["todo"])
    }

    /// `limit`을 넘기지 않는다 — 리스트 자리가 정해져 있어 넘치면 잘려 나갈 뿐이다.
    @Test func stopsAtTheLimit() {
        let items = (15...20).map {
            item(id: "e\($0)", .timedEvent, start: date(day: 13, hour: $0), end: date(day: 13, hour: $0, minute: 30))
        }

        let picked = UpcomingItemPicker.items(
            from: snapshot(items),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["e15", "e16", "e17", "e18"])
    }

    /// **오늘 마감이면 시각이 지나도 남는다** — 아직 안 한 오늘 할 일이기 때문이다.
    ///
    /// 일정과 다른 점이다. 오전에 끝난 회의는 지나간 사실이지만, 오전 9시 마감 할일은
    /// 오후 2시에도 **여전히 해야 할 일**이다. 시각이 지났다고 지우면 그날 할 일이
    /// 위젯에서 사라져, 정작 밀린 것을 볼 수 없다.
    @Test func todaysRemindersSurviveTheirDueTime() {
        let overdueToday = item(id: "overdueToday", .reminder, start: date(day: 13, hour: 9))
        let ahead = item(id: "ahead", .reminder, start: date(day: 13, hour: 20))

        let picked = UpcomingItemPicker.items(
            from: snapshot([overdueToday, ahead]),
            kinds: [.reminder],
            now: now,
            limit: 4,
            calendar: calendar
        )

        // 시간순이라 지난 것이 먼저 온다 — 오늘 할 일이 위에 모인다.
        #expect(picked.map(\.id) == ["overdueToday", "ahead"])
    }

    /// **완료한 할일은 목록에서 뺀다** — 목록은 "아직 할 것"을 세우는 자리다.
    ///
    /// 캘린더 격자의 점은 그대로 남는다(→ `WidgetCalendarDataSource.showsReminder`).
    /// 거기는 "그날 무엇이 있었나"를 보여주는 자리라 규칙이 다르다.
    @Test func completedRemindersAreHiddenFromTheList() {
        let done = item(id: "done", .reminder, start: date(day: 13, hour: 20), isCompleted: true)
        let todo = item(id: "todo", .reminder, start: date(day: 13, hour: 21))

        let picked = UpcomingItemPicker.items(
            from: snapshot([done, todo]),
            kinds: [.reminder],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["todo"])
    }

    /// 완료한 것이 자리를 먹지 않는다 — 그만큼 아직 할 것이 더 올라온다.
    @Test func completedRemindersDoNotConsumeSlots() {
        var items = (15...18).map {
            item(id: "done\($0)", .reminder, start: date(day: 13, hour: $0), isCompleted: true)
        }
        items.append(item(id: "todo", .reminder, start: date(day: 13, hour: 22)))

        let picked = UpcomingItemPicker.items(
            from: snapshot(items),
            kinds: [.reminder],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["todo"])
    }

    /// 어제까지 마감인 할일은 빠진다 — 하루가 지나면 "오늘 할 일"이 아니다.
    ///
    /// 이 컷오프가 없으면 밀린 할일이 계속 쌓여 위젯이 과거로만 채워진다.
    @Test func yesterdaysRemindersDropOut() {
        let yesterday = item(id: "yesterday", .reminder, start: date(day: 12, hour: 9))
        let today = item(id: "today", .reminder, start: date(day: 13, hour: 9))

        var byDay: [Date: [WidgetCalendarItem]] = [:]
        byDay[calendar.startOfDay(for: yesterday.start)] = [yesterday]
        byDay[calendar.startOfDay(for: today.start)] = [today]

        let picked = UpcomingItemPicker.items(
            from: WidgetCalendarSnapshot(itemsByDay: byDay, hasAccess: true),
            kinds: [.reminder],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.map(\.id) == ["today"])
    }

    /// 시간 일정은 **여전히 끝나면 사라진다** — 할일 규칙이 일정까지 번지면 안 된다.
    @Test func pastEventsStillDropOutEvenToday() {
        let finished = item(
            id: "finished", .timedEvent,
            start: date(day: 13, hour: 9), end: date(day: 13, hour: 10)
        )

        let picked = UpcomingItemPicker.items(
            from: snapshot([finished]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.isEmpty)
    }

    /// 지난 것뿐이면 빈 목록 — 위젯은 그때 "없음" 안내를 띄운다.
    @Test func returnsEmptyWhenNothingIsAhead() {
        let past = item(id: "past", .timedEvent, start: date(day: 13, hour: 9), end: date(day: 13, hour: 10))

        let picked = UpcomingItemPicker.items(
            from: snapshot([past]),
            kinds: [.timedEvent, .allDayEvent],
            now: now,
            limit: 4,
            calendar: calendar
        )

        #expect(picked.isEmpty)
    }
}
