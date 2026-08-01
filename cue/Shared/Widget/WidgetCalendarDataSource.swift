//
//  WidgetCalendarDataSource.swift
//  cue / Shared
//
//  홈 화면 위젯이 그릴 일정·미리알림을 EventKit에서 읽어 표시용 DTO로 눕힌다.
//  위젯 익스텐션 프로세스에서 실행된다 — 앱 익스텐션은 컨테이너 앱의 캘린더/미리알림 권한을
//  그대로 물려받으므로 별도 권한 요청이 필요 없다(권한이 없으면 빈 스냅샷 → 위젯이 안내 문구).
//  EventKit 경계 글루라 RED 면제 — 배치·정렬 같은 판단은 전부 순수 타입에 위임한다.
//

import EventKit
import Foundation

/// 날짜별로 묶인 위젯 표시 데이터.
struct WidgetCalendarSnapshot: Sendable {
    /// 날짜(그날 자정) → 그날 항목들. 항목이 없는 날은 키가 없다.
    let itemsByDay: [Date: [WidgetCalendarItem]]
    /// 캘린더·미리알림 접근 권한이 하나라도 있는지 — 없으면 위젯이 안내 문구를 띄운다.
    let hasAccess: Bool

    static let empty = WidgetCalendarSnapshot(itemsByDay: [:], hasAccess: false)

    func items(on day: Date, calendar: Calendar = .current) -> [WidgetCalendarItem] {
        itemsByDay[calendar.startOfDay(for: day)] ?? []
    }
}

enum WidgetCalendarDataSource {

    /// `[from, to)` 구간의 일정 + 미리알림을 날짜별로 묶어 돌려준다.
    ///
    /// 여러 날에 걸친 일정은 **걸치는 날마다** 항목을 복제해 넣는다 — 월 캘린더에서 이틀짜리
    /// 일정이 첫날에만 뜨면 이상하기 때문. 복제본은 원본 시각을 그대로 들고 있어서
    /// `DayTimelineLayout`이 그날 경계로 잘라 그린다.
    static func snapshot(
        from: Date,
        to: Date,
        calendar: Calendar = .current
    ) -> WidgetCalendarSnapshot {
        let eventsAllowed = isAllowed(.event)
        let remindersAllowed = isAllowed(.reminder)
        guard eventsAllowed || remindersAllowed else { return .empty }

        let store = EKEventStore()
        let hidden = hiddenCalendarIDs()
        var items: [WidgetCalendarItem] = []

        if eventsAllowed {
            items += events(store: store, from: from, to: to, hidden: hidden)
        }
        if remindersAllowed {
            items += reminders(store: store, from: from, to: to, hidden: hidden)
        }

        return WidgetCalendarSnapshot(
            itemsByDay: group(items, from: from, to: to, calendar: calendar),
            hasAccess: true
        )
    }

    // MARK: - 조회

    /// 캘린더·미리알림 중 하나라도 읽을 수 있는지 — 갤러리 미리보기가 실제 데이터를 쓸지
    /// 표본으로 대체할지 가른다.
    static var hasAnyAccess: Bool {
        isAllowed(.event) || isAllowed(.reminder)
    }

    private static func isAllowed(_ type: EKEntityType) -> Bool {
        let status = EKEventStore.authorizationStatus(for: type)
        return status == .fullAccess || status == .writeOnly
    }

    private static func events(
        store: EKEventStore,
        from: Date,
        to: Date,
        hidden: Set<String>
    ) -> [WidgetCalendarItem] {
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).compactMap { event in
            guard !hidden.contains(event.calendar.calendarIdentifier),
                  let start = event.startDate, let end = event.endDate else { return nil }
            return WidgetCalendarItem(
                // 반복 일정은 같은 eventIdentifier를 공유하므로 시작 시각을 붙여 회차를 구분한다
                // (ForEach 중복 id는 SwiftUI에서 렌더 누락을 일으킨다).
                id: "\(event.eventIdentifier ?? UUID().uuidString)-\(start.timeIntervalSince1970)",
                title: event.title ?? "",
                start: start,
                end: end,
                kind: event.isAllDay ? .allDayEvent : .timedEvent,
                colorHex: hex(from: event.calendar.cgColor),
                isHighPriority: false,
                isHoliday: HolidayEventPolicy.isHoliday(
                    isSubscribed: event.calendar.isSubscribed,
                    allowsContentModifications: event.calendar.allowsContentModifications,
                    isAllDay: event.isAllDay
                )
            )
        }
    }

    /// 미완료 + 기한이 구간 안에 있는 미리알림만. 완료분은 "지금 잊으면 안 되는" 신호가 아니라 뺀다.
    ///
    /// 그 미리알림을 위젯에 그릴지.
    ///
    /// 미완료는 언제나 그린다. **완료된 것은 오늘 이후 마감만** 남긴다 — 오늘 끝낸 일은
    /// 그날 무엇을 했는지 알려주지만, 지난 것까지 두면 위젯이 이미 끝난 일로 채워져
    /// 지금 해야 할 것이 묻힌다.
    static func showsReminder(isCompleted: Bool, due: Date, today: Date) -> Bool {
        guard isCompleted else { return true }
        return due >= today
    }

    /// EventKit의 미리알림 조회는 콜백 기반이라 세마포어로 동기화한다 — 위젯 타임라인 생성은
    /// 이미 백그라운드 큐에서 돌고, 여기서 async를 위로 전파하면 호출부가 전부 물든다.
    private static func reminders(
        store: EKEventStore,
        from: Date,
        to: Date,
        hidden: Set<String>
    ) -> [WidgetCalendarItem] {
        // **완료된 것까지** 받아온다. 미완료만 주는 `predicateForIncompleteReminders`를 쓰면
        // 오늘 끝낸 할 일이 위젯에서 즉시 사라져, 그날 무엇을 했는지가 남지 않는다.
        // 어느 것을 숨길지는 아래에서 마감일로 가른다.
        let predicate = store.predicateForReminders(in: nil)
        let semaphore = DispatchSemaphore(value: 0)
        var fetched: [EKReminder] = []
        store.fetchReminders(matching: predicate) { reminders in
            fetched = reminders ?? []
            semaphore.signal()
        }
        // 조회가 매달리면 위젯 갱신 전체가 멈춘다 — 일정만이라도 그리도록 짧게 포기한다.
        guard semaphore.wait(timeout: .now() + 5) == .success else { return [] }

        let today = Calendar.current.startOfDay(for: Date())

        return fetched.compactMap { reminder in
            guard !hidden.contains(reminder.calendar.calendarIdentifier),
                  let due = reminder.dueDateComponents?.date,
                  // 전체를 받아왔으므로 표시 구간은 직접 자른다.
                  due >= from, due < to else { return nil }
            guard showsReminder(isCompleted: reminder.isCompleted, due: due, today: today) else {
                return nil
            }
            return WidgetCalendarItem(
                // 마감 시각을 붙여 구분한다 — 반복 미리알림은 여러 회차가 같은
                // `calendarItemIdentifier`를 갖는다. 그대로 두면 창 안에 두 회차가 들어올 때
                // `ForEach`가 id 충돌로 하나를 통째로 버린다(일정 쪽은 이미 같은 규칙이다).
                id: "\(reminder.calendarItemIdentifier)-\(due.timeIntervalSince1970)",
                title: reminder.title ?? "",
                start: due,
                // 미리알림은 길이가 없다 — 타임라인이 최소 높이를 준다.
                end: due,
                kind: .reminder,
                colorHex: hex(from: reminder.calendar.cgColor),
                // EventKit 우선순위는 0=미지정, 1~9=높음~낮음. 지정된 것만 마커를 채운다.
                isHighPriority: reminder.priority != 0,
                isCompleted: reminder.isCompleted
            )
        }
    }

    // MARK: - 날짜별 묶기

    /// 걸치는 날마다 항목을 복제해 날짜별 사전으로. 요청 구간 밖의 날은 만들지 않는다.
    private static func group(
        _ items: [WidgetCalendarItem],
        from: Date,
        to: Date,
        calendar: Calendar
    ) -> [Date: [WidgetCalendarItem]] {
        let lowerBound = calendar.startOfDay(for: from)
        var result: [Date: [WidgetCalendarItem]] = [:]

        for item in items {
            // 종일 일정의 endDate는 마지막 날 23:59:59라 그대로 쓰면 되지만, 시간 일정이 자정
            // 정각에 끝나면 다음 날까지 번진다 — 1초 당겨 끝나는 날을 제 날에 묶는다.
            let rawEnd = max(item.start, item.end)
            let lastMoment = rawEnd > item.start ? rawEnd.addingTimeInterval(-1) : rawEnd

            var day = max(calendar.startOfDay(for: item.start), lowerBound)
            let lastDay = calendar.startOfDay(for: lastMoment)
            while day <= lastDay, day < to {
                result[day, default: []].append(item)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        return result.mapValues { MonthWidgetPacker.sorted($0) }
    }

    // MARK: - 공유 설정

    /// 앱에서 숨긴 캘린더 — LA 월간 캘린더(`LiveMonthCalendarProvider`)와 같은 App Group 키를 읽는다.
    private static func hiddenCalendarIDs() -> Set<String> {
        Set(SharedAppGroup.defaults.stringArray(forKey: SharedAppGroup.Keys.hiddenCalendarIDs) ?? [])
    }

    /// `CGColor` → "#RRGGBB". `LiveMonthCalendarProvider.hex`와 같은 규칙.
    private static func hex(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let channel: (CGFloat) -> Int = { Int(round(max(0, min(1, $0)) * 255)) }
        return String(
            format: "#%02X%02X%02X",
            channel(components[0]), channel(components[1]), channel(components[2])
        )
    }
}
