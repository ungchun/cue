//
//  LiveActivityUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct LiveActivityUseCaseTests {

    // MARK: - StartReminder — cap / remaining / mapping

    @Test func startReminderCapsItemsAtStorageLimitAndComputesRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...25).map { reminder(id: "r\($0)", title: "할일 \($0)") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘",
            reminders: reminders,
            listColors: [:]
        )

        let calls = await service.startReminderCalls
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.listTitle == "오늘")
        // 표시는 6개지만 backfill용으로 20개까지 싣는다.
        #expect(call.items.count == 20)
        #expect(call.items.first?.id == "r1")
        #expect(call.items.last?.id == "r20")
        #expect(call.remaining == 5)
    }

    @Test func startReminderUnderStorageLimitKeepsAllForBackfill() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...8).map { reminder(id: "r\($0)", title: "할일 \($0)") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘",
            reminders: reminders,
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        // 8개 전부 싣어야 체크로 하나 빠져도 위젯 6칸이 안 빈다.
        #expect(call.items.count == 8)
        #expect(call.remaining == 0)
    }

    @Test func startReminderMapsEachItemListColor() async throws {
        let service = RecordingLiveActivityService()
        let reminders = [
            reminder(id: "r1", title: "회사 일", listID: "work"),
            reminder(id: "r2", title: "개인 일", listID: "personal"),
            reminder(id: "r3", title: "색 없는 리스트", listID: "nocolor"),
        ]

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "전체",
            reminders: reminders,
            listColors: ["work": "#FF9500", "personal": "#34C759"]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.map(\.colorHex) == ["#FF9500", "#34C759", nil])
    }

    @Test func startReminderWithExactCapHasZeroRemaining() async throws {
        let service = RecordingLiveActivityService()
        let reminders = (1...20).map { reminder(id: "r\($0)", title: "X") }

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "전체",
            reminders: reminders,
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.count == 20)
        #expect(call.remaining == 0)
    }

    @Test func startReminderEmptyListPassesEmptyItems() async throws {
        let service = RecordingLiveActivityService()

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "비어있음",
            reminders: [],
            listColors: [:]
        )

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.isEmpty)
        #expect(call.remaining == 0)
    }

    // MARK: - todayCount — 오늘 할일 카운트(주간 캘린더 스트립 우상단)

    @Test func reminderTodayCountIncludesTodayDueAndUndatedExcludesRest() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(12 * 3600)
        let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart)!.addingTimeInterval(9 * 3600)
        let todayDue = todayStart.addingTimeInterval(15 * 3600)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!.addingTimeInterval(9 * 3600)

        let reminders = [
            reminder(id: "undated", title: "미지정"),                                       // nil → 포함
            reminder(id: "today", title: "오늘", dueDate: todayDue),                        // 오늘 → 포함
            reminder(id: "overdue", title: "지남", dueDate: yesterday),                     // overdue → 제외
            reminder(id: "future", title: "미래", dueDate: tomorrow),                       // 미래 → 제외
            reminder(id: "doneToday", title: "완료", isCompleted: true, dueDate: todayDue), // 완료 → 제외
            reminder(id: "doneUndated", title: "완료2", isCompleted: true),                 // 완료 → 제외
        ]

        #expect(StartReminderLiveActivityUseCase.todayCount(reminders, now: now) == 2)
    }

    @Test func reminderTodayCountIncludesDueAtMidnightExcludesJustBefore() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(12 * 3600)
        let atMidnight = reminder(id: "mid", title: "자정", dueDate: todayStart)               // 오늘 0시 → 포함
        let justBefore = reminder(id: "before", title: "직전", dueDate: todayStart.addingTimeInterval(-1)) // 어제 → 제외

        #expect(StartReminderLiveActivityUseCase.todayCount([atMidnight, justBefore], now: now) == 1)
    }

    @Test func startReminderCarriesTodayCount() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let now = cal.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        let reminders = [
            reminder(id: "a", title: "미지정"),
            reminder(id: "b", title: "지남", dueDate: cal.date(byAdding: .day, value: -1, to: now)),
        ]

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘", reminders: reminders, listColors: [:], now: now
        )

        #expect(await service.startReminderCalls.first?.todayCount == 1)
    }

    @Test func scheduleTodayEventCountCountsAllDayAndUnendedTimed() {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(12 * 3600)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!

        let events = [
            event(id: "allday", title: "종일", start: todayStart, end: todayStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true),  // 포함
            event(id: "unended", title: "예정", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: nil),         // 포함
            event(id: "ongoing", title: "진행", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(1800), colorHex: nil),         // 포함(end>now)
            event(id: "ended", title: "끝남", start: todayStart.addingTimeInterval(8 * 3600), end: now.addingTimeInterval(-3600), colorHex: nil), // 제외
            event(id: "tomorrow", title: "내일", start: tomorrow.addingTimeInterval(9 * 3600), end: tomorrow.addingTimeInterval(10 * 3600), colorHex: nil), // 제외
            event(id: "tmrAllDay", title: "내일종일", start: tomorrow, end: tomorrow.addingTimeInterval(86_400), colorHex: nil, isAllDay: true), // 제외(오늘 아님)
        ]

        #expect(StartScheduleLiveActivityUseCase.todayEventCount(events, now: now) == 3)
    }

    /// 일정 LA 발행 시 이번 주(오늘 제외) 캘린더 이벤트가 주간 스트립 점으로 실린다.
    @Test func startScheduleCarriesWeekEventDots() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(6 * 3600)
        // 오늘 일정(발행 트리거) + 내일 일정(스트립 점 대상, 같은 주라고 가정).
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let events = [
            event(id: "today", title: "오늘", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: "#FF0000"),
            event(id: "tmr", title: "내일", start: tomorrow.addingTimeInterval(3600), end: tomorrow.addingTimeInterval(7200), colorHex: "#00FF00"),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, weekEvents: events, now: now)

        let dots = try #require(await service.startScheduleCalls.first?.weekEventDots)
        // 오늘은 제외되고, 내일 점만(초록) 실린다. (내일이 이번 주 안일 때.)
        #expect(dots.allSatisfy { !cal.isDate($0.dayStart, inSameDayAs: now) })
    }

    /// 할일 LA도 같은 주간 스트립을 그리므로 캘린더 이벤트 점을 함께 싣는다.
    @Test func startReminderCarriesWeekEventDots() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(6 * 3600)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: todayStart)!
        let weekEvents = [
            event(id: "tmr", title: "내일", start: tomorrow.addingTimeInterval(3600), end: tomorrow.addingTimeInterval(7200), colorHex: "#00FF00"),
        ]

        try await StartReminderLiveActivityUseCase(service: service)(
            listTitle: "오늘", reminders: [reminder(id: "a", title: "할일")],
            listColors: [:], weekEvents: weekEvents, now: now
        )

        let dots = try #require(await service.startReminderCalls.first?.weekEventDots)
        #expect(dots.allSatisfy { !cal.isDate($0.dayStart, inSameDayAs: now) })
    }

    @Test func startScheduleCarriesTodayCount() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: .now)
        let now = todayStart.addingTimeInterval(6 * 3600)
        let events = [
            event(id: "allday", title: "종일", start: todayStart, end: todayStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true),
            event(id: "timed", title: "오늘예정", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: nil),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: now)

        #expect(await service.startScheduleCalls.first?.todayCount == 2)
    }

    // MARK: - ContentState.removingItem — LA에서 완료 항목 제거

    @Test func removingItemDropsMatchingItemAndLowersCount() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [
                LiveReminderItem(id: "r1", title: "A", colorHex: nil),
                LiveReminderItem(id: "r2", title: "B", colorHex: nil),
                LiveReminderItem(id: "r3", title: "C", colorHex: nil),
            ],
            remaining: 2
        )

        let next = state.removingItem(id: "r2")

        #expect(next.items.map(\.id) == ["r1", "r3"])
        #expect(next.remaining == 2)
        // 표시 카운트(items + remaining)는 5 → 4로 1 감소.
        #expect(next.items.count + next.remaining == 4)
    }

    @Test func removingUnknownItemLeavesStateUnchanged() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [LiveReminderItem(id: "r1", title: "A", colorHex: nil)],
            remaining: 0,
            todayCount: 3
        )

        let next = state.removingItem(id: "nope")

        #expect(next.items.map(\.id) == ["r1"])
        #expect(next.remaining == 0)
        #expect(next.todayCount == 3)   // 아무것도 안 빠지면 카운트 유지
    }

    @Test func removingItemDecrementsTodayCountFlooringAtZero() {
        let state = ReminderLiveActivityAttributes.ContentState(
            items: [LiveReminderItem(id: "r1", title: "A", colorHex: nil)],
            remaining: 0,
            todayCount: 1
        )

        let next = state.removingItem(id: "r1")
        #expect(next.todayCount == 0)

        // 0에서 또 빼도 음수로 안 내려감(이미 없는 항목이라 제거도 안 일어남 → 유지).
        #expect(next.removingItem(id: "r1").todayCount == 0)
    }

    // MARK: - StartSchedule — 날짜 그룹핑 + 라벨 + 종일 정렬

    @Test func startScheduleGroupsByDayWithRelativeLabels() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let baseDay = cal.startOfDay(for: .now)
        // now를 그날 06:00로 고정하고 이벤트는 09:00~ → 실제 시계와 무관하게 지난-이벤트 필터에 안 걸림.
        let now = baseDay.addingTimeInterval(6 * 3600)
        let day = { (offset: Int) in cal.date(byAdding: .day, value: offset, to: baseDay)! }

        let events = [
            event(id: "t1", title: "오늘일정", start: day(0).addingTimeInterval(9 * 3600), end: day(0).addingTimeInterval(10 * 3600), colorHex: "#FF0000"),
            event(id: "m1", title: "내일일정", start: day(1).addingTimeInterval(9 * 3600), end: day(1).addingTimeInterval(10 * 3600), colorHex: nil),
            event(id: "mo1", title: "모레일정", start: day(2).addingTimeInterval(9 * 3600), end: day(2).addingTimeInterval(10 * 3600), colorHex: nil),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: now)

        let days = try #require(await service.startScheduleCalls.first).days
        // 로케일 무관 검증 — 코드·테스트가 같은 키를 해석하므로 어느 언어에서든 일치.
        // 상대 표기는 오늘/내일까지만 — 2일 뒤부터는 날짜 표기(dateLabel).
        #expect(days.map(\.label) == [
            String(localized: "Today"), String(localized: "Tomorrow"),
            StartScheduleLiveActivityUseCase.dateLabel(for: day(2)),
        ])
        // id는 4KB 절약용 합성 인덱스 — 원본 대응은 제목으로 확인한다.
        #expect(days.map { $0.events.map(\.title) } == [["오늘일정"], ["내일일정"], ["모레일정"]])
        #expect(days.first?.events.first?.calendarColorHex == "#FF0000")
    }

    @Test func startScheduleLabelsFarDayAsDateNotRelative() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let day3 = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: .now))!
        let events = [event(id: "f1", title: "먼일정", start: day3.addingTimeInterval(3600), end: day3.addingTimeInterval(7200), colorHex: nil)]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: .now)

        let label = try #require(await service.startScheduleCalls.first?.days.first?.label)
        // 3일 뒤는 오늘/내일이 아니라 날짜 형식 — 로케일 무관(공유 규칙과 일치 검증).
        let relative = [String(localized: "Today"), String(localized: "Tomorrow")]
        #expect(!relative.contains(label))
        #expect(label == StartScheduleLiveActivityUseCase.dateLabel(for: day3))
    }

    /// 먼 날짜 라벨 로케일 계약 — 한국어는 "7월 28일" 자연 표기, 그 외는 로케일 관습 순서.
    /// 고정 "M/d" 포맷은 일-월 순서 국가(영국 등)에서 날짜 오독을 일으켜 템플릿으로 바꿨다.
    @Test func dateLabelUsesKoreanNaturalFormAndLocalizedOrderElsewhere() throws {
        let date = try #require(
            DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 7, day: 28).date
        )

        #expect(StartScheduleLiveActivityUseCase.dateLabel(for: date, locale: Locale(identifier: "ko_KR")) == "7월 28일")

        // 일-월 순서 로케일 — 고정 M/d("7/28")가 아니라 일이 먼저 와야 한다.
        let gb = StartScheduleLiveActivityUseCase.dateLabel(for: date, locale: Locale(identifier: "en_GB"))
        #expect(!gb.contains("7/28"))
        #expect(gb.contains("28"))
    }

    @Test func startScheduleCapsTotalEventsForContentStateLimit() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // 5일 × 6개 = 30개 — 4KB 한도 위험. use case가 총량을 잘라야 한다.
        let events = (0..<5).flatMap { dayOffset in
            (0..<6).map { i in
                let day = cal.date(byAdding: .day, value: dayOffset, to: today)!
                return event(
                    id: "d\(dayOffset)-e\(i)", title: "일정",
                    start: day.addingTimeInterval(Double(3600 * (i + 1))),
                    end: day.addingTimeInterval(Double(3600 * (i + 2))),
                    colorHex: nil
                )
            }
        }

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: .now)

        let days = try #require(await service.startScheduleCalls.first).days
        let total = days.reduce(0) { $0 + $1.events.count }
        #expect(total <= StartScheduleLiveActivityUseCase.maxTotalEvents)
    }

    /// 일수 제한(옛 maxDays=5)을 없앴다 — 총량 한도 안이면 5일을 넘는 날도 모두 싣는다.
    @Test func startScheduleIncludesMoreThanFiveDaysUnderTotalCap() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // 7일에 하루 1개씩 = 7개(< maxTotalEvents). 기준 now를 자정으로 둬 오늘 일정도 미래로 포함.
        let events = (0..<7).map { dayOffset -> CalendarEvent in
            let day = cal.date(byAdding: .day, value: dayOffset, to: today)!
            return event(
                id: "d\(dayOffset)", title: "일정",
                start: day.addingTimeInterval(10 * 3600),
                end: day.addingTimeInterval(11 * 3600),
                colorHex: nil
            )
        }

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: today)

        let days = try #require(await service.startScheduleCalls.first).days
        #expect(days.count == 7)
    }

    @Test func startScheduleExcludesPastDaysEntirely() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let now = cal.startOfDay(for: .now).addingTimeInterval(10 * 3600)  // 오늘 10:00
        let yStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: now))!

        // EventKit straddling으로 딸려오는 어제 종일/멀티데이를 시뮬레이션.
        let yesterdayAllDay = event(id: "yall", title: "어제종일", start: yStart, end: yStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true)
        let yesterdayMultiDay = event(id: "ymulti", title: "멀티데이", start: yStart.addingTimeInterval(9 * 3600), end: cal.startOfDay(for: now).addingTimeInterval(9 * 3600), colorHex: nil)
        let todayUpcoming = event(id: "t", title: "오늘예정", start: cal.startOfDay(for: now).addingTimeInterval(14 * 3600), end: cal.startOfDay(for: now).addingTimeInterval(15 * 3600), colorHex: nil)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [yesterdayAllDay, yesterdayMultiDay, todayUpcoming], now: now)

        let days = try #require(await service.startScheduleCalls.first).days
        // id는 4KB 절약용 합성 인덱스로 바뀌므로 제목으로 판별한다.
        let titles = days.flatMap { $0.events.map(\.title) }
        #expect(!titles.contains("어제종일"))    // 어제 종일 제외
        #expect(!titles.contains("멀티데이"))    // 어제 시작 멀티데이 제외
        #expect(titles.contains("오늘예정"))     // 오늘 예정 표시
        #expect(days.first?.label == String(localized: "Today"))
    }

    @Test func startScheduleSkipsWhenNoUpcomingEvents() async throws {
        let service = RecordingLiveActivityService()

        let started = try await StartScheduleLiveActivityUseCase(service: service)(events: [], now: .now)

        #expect(started == false)
        #expect(await service.startScheduleCalls.isEmpty)   // 빈 일정이면 게시 자체를 안 한다
    }

    @Test func startScheduleSkipsWhenAllEventsEnded() async throws {
        let service = RecordingLiveActivityService()
        let now = Date.now
        let ended = event(id: "e", title: "끝남", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), colorHex: nil)

        let started = try await StartScheduleLiveActivityUseCase(service: service)(events: [ended], now: now)

        #expect(started == false)
        #expect(await service.startScheduleCalls.isEmpty)
    }

    @Test func startScheduleHidesEndedTimedEventsButKeepsAllDay() async throws {
        let service = RecordingLiveActivityService()
        let now = Date.now
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)

        let ended = event(id: "ended", title: "끝남", start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), colorHex: nil)
        let ongoing = event(id: "ongoing", title: "진행중", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(1800), colorHex: nil)
        let future = event(id: "future", title: "예정", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), colorHex: nil)
        // 종일은 시작이 자정(과거)이라도 항상 유지.
        let allDay = event(id: "allday", title: "종일", start: todayStart, end: todayStart.addingTimeInterval(86_400), colorHex: nil, isAllDay: true)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [ended, ongoing, future, allDay], now: now)

        let days = try #require(await service.startScheduleCalls.first).days
        // id는 4KB 절약용 합성 인덱스로 바뀌므로 제목으로 판별한다.
        let titles = days.flatMap { $0.events.map(\.title) }
        #expect(!titles.contains("끝남"))     // 끝난 시간 이벤트 제외
        #expect(titles.contains("진행중"))    // 진행 중 유지
        #expect(titles.contains("예정"))      // 예정 유지
        #expect(titles.contains("종일"))      // 종일은 항상 유지
    }

    @Test func startScheduleSortsByStartTimeWithinDay() async throws {
        // 인앱(ScheduleViewModel)과 동일하게 순수 시작시간순. 종일은 시작이 자정(00:00)이라
        // 같은 날 시간 일정보다 자연히 위로 온다.
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // now를 06:00로 고정, 시간 이벤트는 09:00~ → 지난-이벤트 필터에 안 걸리게.
        let now = today.addingTimeInterval(6 * 3600)
        let events = [
            event(id: "timed", title: "시간일정", start: today.addingTimeInterval(9 * 3600), end: today.addingTimeInterval(10 * 3600), colorHex: nil, isAllDay: false),
            event(id: "allday", title: "종일일정", start: today, end: today.addingTimeInterval(86_400), colorHex: nil, isAllDay: true),
        ]

        try await StartScheduleLiveActivityUseCase(service: service)(events: events, now: now)

        let firstDay = try #require(await service.startScheduleCalls.first?.days.first)
        #expect(firstDay.events.map(\.title) == ["종일일정", "시간일정"])   // 00:00 < 09:00
    }

    // MARK: - 멀티데이 끌어올림 + timeText 굽기

    @Test func startSchedulePullsOngoingMultiDayIntoTodayAsInProgress() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let now = today.addingTimeInterval(22 * 3600)   // 오늘 22:00
        // 이틀 전 시작 ~ 이틀 후 종료 (오늘 진행 중).
        let start = cal.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(6 * 3600)
        let end = cal.date(byAdding: .day, value: 2, to: today)!.addingTimeInterval(8 * 3600)
        let multi = event(id: "multi", title: "여러날", start: start, end: end, colorHex: nil)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [multi], now: now)

        let days = try #require(await service.startScheduleCalls.first).days
        #expect(days.first?.label == String(localized: "Today"))                 // 지난 날짜 헤더 아니라 오늘로
        let item = try #require(days.first?.events.first)
        #expect(item.title == "여러날")
        #expect(item.timeText == String(localized: "In progress"))
    }

    @Test func startScheduleMultiDayEndingTodayShowsArrowEndTime() async throws {
        let service = RecordingLiveActivityService()
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let now = today.addingTimeInterval(22 * 3600)
        let start = cal.date(byAdding: .day, value: -2, to: today)!.addingTimeInterval(6 * 3600)
        let end = today.addingTimeInterval(23 * 3600)   // 오늘 23:00 종료
        let multi = event(id: "ending", title: "오늘끝", start: start, end: end, colorHex: nil)

        try await StartScheduleLiveActivityUseCase(service: service)(events: [multi], now: now)

        let item = try #require(await service.startScheduleCalls.first?.days.first?.events.first)
        #expect(item.timeText.hasPrefix("→"))   // "→ 오후 11:00"
    }

    // MARK: - Wrappers — forwarding (Reminder/Schedule. 집중 LA는 AlarmKit으로 이관됨)

    @Test func endReminderCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await EndReminderLiveActivityUseCase(service: service)()

        #expect(await service.endReminderCount == 1)
    }

    @Test func endScheduleCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await EndScheduleLiveActivityUseCase(service: service)()

        #expect(await service.endScheduleCount == 1)
    }

    @Test func syncCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await SyncLiveActivitiesUseCase(service: service)()

        #expect(await service.syncCount == 1)
    }

    /// 설정(캘린더 표시 등) 변경 직후 켜져 있는 LA를 다시 그리게 하는 위임 — 서비스로 그대로 전달.
    @Test func refreshLayoutCallsServiceOnce() async {
        let service = RecordingLiveActivityService()

        await RefreshLiveActivityLayoutUseCase(service: service)()

        #expect(await service.refreshLayoutCount == 1)
    }

    // MARK: - StartSampleLiveActivities (온보딩 목업 3종 게시의 일정·할일)

    /// 온보딩 목업 일정 — 오늘 하루 묶음(종일 1 + 시간 2), 월간 캘린더 강제 표시.
    /// 설정 미러를 건드리지 않고 캘린더가 보이려면 오버라이드가 반드시 true여야 한다.
    @Test func samplePublishesTodayScheduleWithCalendarOverride() async throws {
        let service = RecordingLiveActivityService()
        let useCase = StartSampleLiveActivitiesUseCase(
            startSchedule: StartScheduleLiveActivityUseCase(service: service),
            startReminder: StartReminderLiveActivityUseCase(service: service)
        )

        await useCase(now: Date(timeIntervalSince1970: 1_784_000_000))

        let calls = await service.startScheduleCalls
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.showsCalendarOverride == true)
        #expect(call.days.count == 1)                     // 오늘 하루 묶음만
        let events = try #require(call.days.first?.events)
        #expect(events.count == 3)
        #expect(events.filter(\.isAllDay).count == 1)     // 종일 캡슐 1 + 시간 막대 2 — 두 형태를 다 보여준다
        #expect(events.allSatisfy { !$0.title.isEmpty })
    }

    /// 온보딩 목업 할일 — 예시 6개, 합성 id(EventKit 식별자와 절대 안 겹침 → 체크 인텐트가
    /// 자연히 no-op), 오늘 카운트 6.
    @Test func samplePublishesSixTasksWithSyntheticIDs() async throws {
        let service = RecordingLiveActivityService()
        let useCase = StartSampleLiveActivitiesUseCase(
            startSchedule: StartScheduleLiveActivityUseCase(service: service),
            startReminder: StartReminderLiveActivityUseCase(service: service)
        )

        await useCase(now: Date(timeIntervalSince1970: 1_784_000_000))

        let calls = await service.startReminderCalls
        #expect(calls.count == 1)
        let call = try #require(calls.first)
        #expect(call.items.count == 6)
        #expect(call.items.allSatisfy { $0.id.hasPrefix(StartSampleLiveActivitiesUseCase.sampleReminderIDPrefix) })
        #expect(call.items.allSatisfy { !$0.title.isEmpty })
        #expect(call.remaining == 0)
        #expect(call.todayCount == 6)
    }

    /// 일정 게시가 실패해도 할일 목업은 게시된다 — 목업은 조연이라 best-effort로 삼킨다.
    @Test func sampleStillPublishesTasksWhenScheduleFails() async {
        let service = ScheduleFailingLiveActivityService()
        let useCase = StartSampleLiveActivitiesUseCase(
            startSchedule: StartScheduleLiveActivityUseCase(service: service),
            startReminder: StartReminderLiveActivityUseCase(service: service)
        )

        await useCase(now: Date(timeIntervalSince1970: 1_784_000_000))

        #expect(await service.startReminderCount == 1)
    }

    // MARK: - Helpers

    private func reminder(id: String, title: String, listID: String = "list-1", isCompleted: Bool = false, dueDate: Date? = nil) -> Reminder {
        Reminder(
            id: id,
            title: title,
            isCompleted: isCompleted,
            notes: nil,
            dueDate: dueDate,
            listID: listID
        )
    }

    private func event(id: String, title: String, start: Date, end: Date, colorHex: String?, isAllDay: Bool = false) -> CalendarEvent {
        CalendarEvent(
            id: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            calendarColorHex: colorHex,
            isReadOnly: false
        )
    }
}

// MARK: - Mock service — actor로 호출 기록을 안전하게 보관

private final actor RecordingLiveActivityService: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startReminderCalls: [(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots])] = []
    private(set) var endReminderCount = 0

    private(set) var startScheduleCalls: [(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?)] = []
    private(set) var endScheduleCount = 0

    private(set) var startMemoCalls: [(text: String, colorHex: String, textColorHex: String)] = []
    private(set) var endMemoCount = 0

    private(set) var syncCount = 0
    private(set) var refreshLayoutCount = 0

    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int,
        todayCount: Int,
        weekEventDots: [LiveDayEventDots]
    ) async throws {
        startReminderCalls.append((listTitle, items, remaining, todayCount, weekEventDots))
    }

    func endReminder() async {
        endReminderCount += 1
    }

    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {
        startScheduleCalls.append((days, todayCount, weekEventDots, showsCalendarOverride))
    }

    func endSchedule() async {
        endScheduleCount += 1
    }

    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {
        startMemoCalls.append((text, colorHex, textColorHex))
    }

    func endMemo() async {
        endMemoCount += 1
    }

    func sync() async {
        syncCount += 1
    }

    func refreshLayout() async {
        refreshLayoutCount += 1
    }
}

/// startSchedule만 throw하는 실패 주입 더블 — 목업 use case의 best-effort 검증용.
private final actor ScheduleFailingLiveActivityService: LiveActivityService {
    var isEnabled: Bool { true }

    private(set) var startReminderCount = 0

    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int,
        todayCount: Int,
        weekEventDots: [LiveDayEventDots]
    ) async throws {
        startReminderCount += 1
    }

    func endReminder() async {}

    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {
        throw DomainError.validation("test")
    }

    func endSchedule() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {}
    func endMemo() async {}
    func sync() async {}
    func refreshLayout() async {}
}
