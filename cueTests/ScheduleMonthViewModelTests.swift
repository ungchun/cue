//
//  ScheduleMonthViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ScheduleMonthViewModelTests {

    /// 고정 기준 시각 — 2026-11-15 12:00(기기 시간대). "이번 달" = 2026년 11월.
    private let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!

    private let listA = ReminderList(id: "list-a", title: "개인", colorHex: "#FF9500")

    private func date(_ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, year: Int = 2026) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// 그 달 1일 ~ 다음 달 1일 — VM이 달 하나를 조회하는 범위.
    private func monthRange(_ month: Int, year: Int = 2026) -> DateInterval {
        let start = date(month, 1, year: year)
        return DateInterval(start: start, end: Calendar.current.date(byAdding: .month, value: 1, to: start)!)
    }

    private func event(id: String, title: String, day: Date, calendarID: String = "cal-a") -> CalendarEvent {
        CalendarEvent(
            id: id, title: title,
            startDate: day.addingTimeInterval(10 * 60 * 60),
            endDate: day.addingTimeInterval(11 * 60 * 60),
            isAllDay: false, calendarColorHex: "#0A84FF",
            isReadOnly: false, calendarID: calendarID
        )
    }

    private func reminder(id: String, title: String, due: Date?) -> Reminder {
        Reminder(id: id, title: title, isCompleted: false, notes: nil,
                 dueDate: due, includesTime: true, listID: listA.id)
    }

    /// 월 VM이 쓰는 의존성만 인메모리로 바꿔 끼운다 — 나머지는 프리뷰 묶음 그대로(쓰이지 않음).
    /// 디바운스는 0 — 테스트가 `waitForWindowLoad`로 결정론적으로 기다린다.
    private func makeViewModel(
        eventsAccess: EventsAccess = .granted,
        events: [CalendarEvent] = [],
        remindersRepository: InMemoryRemindersRepository? = nil,
        appSettings: AppSettings = .default,
        snapshotCache: RecordingSnapshotCache = RecordingSnapshotCache(),
        clock: MutableClock? = nil,
        weather: InMemoryWeatherRepository = InMemoryWeatherRepository(),
        isLunarDateAvailable: Bool = false
    ) -> (ScheduleMonthViewModel, RecordingEventsRepository, RecordingSnapshotCache) {
        let eventsRepository = RecordingEventsRepository(
            InMemoryEventsRepository(access: eventsAccess, events: events)
        )
        let remindersRepository = remindersRepository ?? InMemoryRemindersRepository(access: .granted)
        let settingsRepository = InMemoryAppSettingsRepository(storage: appSettings)
        var dependencies = Dependencies.preview
        dependencies.currentEventsAccess = CurrentEventsAccessUseCase(repository: eventsRepository)
        dependencies.fetchEvents = FetchEventsUseCase(repository: eventsRepository)
        dependencies.observeEventsChanges = ObserveEventsChangesUseCase(repository: eventsRepository)
        dependencies.fetchAppSettings = FetchAppSettingsUseCase(repository: settingsRepository)
        dependencies.currentRemindersAccess = CurrentRemindersAccessUseCase(repository: remindersRepository)
        dependencies.fetchReminders = FetchRemindersUseCase(repository: remindersRepository)
        dependencies.fetchReminderLists = FetchReminderListsUseCase(repository: remindersRepository)
        dependencies.observeRemindersChanges = ObserveRemindersChangesUseCase(repository: remindersRepository)
        dependencies.loadMonthEventsSnapshot = LoadMonthEventsSnapshotUseCase(repository: snapshotCache)
        dependencies.saveMonthEventsSnapshot = SaveMonthEventsSnapshotUseCase(repository: snapshotCache)
        dependencies.loadRemindersSnapshot = LoadRemindersSnapshotUseCase(repository: snapshotCache)
        dependencies.fetchDailyWeather = FetchDailyWeatherUseCase(repository: weather)
        dependencies.isLunarDateAvailable = isLunarDateAvailable
        let fixedNow = now
        let nowProvider: () -> Date
        if let clock {
            nowProvider = { clock.now }
        } else {
            nowProvider = { fixedNow }
        }
        let viewModel = ScheduleMonthViewModel(dependencies: dependencies, now: nowProvider, debounce: .zero)
        return (viewModel, eventsRepository, snapshotCache)
    }

    /// 비동기 상태를 짧게 기다린다(bounded — 최대 ~1s).
    private func waitUntil(_ condition: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    // MARK: - 표시

    @Test func visibleMonthTitleFollowsVisibleOffset() {
        let (viewModel, _, _) = makeViewModel()
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")

        #expect(viewModel.visibleMonthTitle == formatter.string(from: date(11, 1)))

        viewModel.visibleOffset = 1
        #expect(viewModel.visibleMonthTitle == formatter.string(from: date(12, 1)))
    }

    @Test func visibleMonthNameAndYearFollowVisibleOffset() {
        let (viewModel, _, _) = makeViewModel()
        let monthName = DateFormatter()
        monthName.setLocalizedDateFormatFromTemplate("MMMM")
        let year = Calendar.current.component(.year, from: date(12, 1))

        #expect(viewModel.visibleMonthName == monthName.string(from: date(11, 1)))
        #expect(viewModel.visibleYear == year.formatted(.number.grouping(.never)))

        // 12월 → 다음 해 1월: 연도가 함께 넘어간다.
        viewModel.visibleOffset = 2
        #expect(viewModel.visibleMonthName == monthName.string(from: date(1, 1, year: year + 1)))
        #expect(viewModel.visibleYear == (year + 1).formatted(.number.grouping(.never)))
    }

    @Test func pageGridPointsAtMonthRelativeToNowUpToTenYears() {
        let (viewModel, _, _) = makeViewModel()

        #expect(viewModel.monthOffsets == -120...120)
        #expect(viewModel.page(for: 0).grid.year == 2026)
        #expect(viewModel.page(for: 0).grid.month == 11)
        #expect(viewModel.page(for: -1).grid.month == 10)
        #expect(viewModel.page(for: 2).grid.year == 2027)
        #expect(viewModel.page(for: 2).grid.month == 1)
        // 라이브 액티비티의 ±12 제한을 받지 않는다.
        #expect(viewModel.page(for: 120).grid.year == 2036)
        #expect(viewModel.page(for: -120).grid.year == 2016)
        #expect(viewModel.page(for: 0).monthStart == date(11, 1))
    }

    @Test func jumpMovesToThatMonthAndClampsToRange() {
        let (viewModel, _, _) = makeViewModel()

        #expect(viewModel.monthRange == date(11, 1, year: 2016)...date(11, 1, year: 2036))

        viewModel.jump(to: date(3, 20, year: 2027))
        #expect(viewModel.visibleOffset == 4)
        #expect(viewModel.visibleMonthStart == date(3, 1, year: 2027))

        viewModel.jump(to: date(1, 1, year: 2050))
        #expect(viewModel.visibleOffset == 120)

        viewModel.jump(to: date(6, 1, year: 1990))
        #expect(viewModel.visibleOffset == -120)
    }

    /// 앱을 켜 둔 채 달이 바뀌어도 오프셋↔달 매핑·제목은 처음 연 달 기준 그대로다.
    @Test func monthChangeWhileRunningKeepsOffsetToMonthMapping() {
        let clock = MutableClock(now)
        let (viewModel, _, _) = makeViewModel(clock: clock)
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        let november = viewModel.page(for: 0)

        clock.now = date(12, 2, hour: 9)

        #expect(viewModel.visibleMonthTitle == formatter.string(from: date(11, 1)))
        #expect(viewModel.visibleMonthStart == date(11, 1))
        #expect(viewModel.page(for: 0) === november)
        #expect(viewModel.page(for: 0).monthStart == date(11, 1))
        #expect(viewModel.page(for: 1).monthStart == date(12, 1))
        #expect(viewModel.monthRange == date(11, 1, year: 2016)...date(11, 1, year: 2036))

        viewModel.jump(to: date(12, 10))
        #expect(viewModel.visibleOffset == 1)
        #expect(viewModel.visibleMonthTitle == formatter.string(from: date(12, 1)))
    }

    /// 달이 바뀌어도 이미 받은 오프셋 0 페이지는 11월 일정을 그대로 보여 준다.
    @Test func monthChangeWhileRunningKeepsFetchingAnchorMonths() async {
        let clock = MutableClock(now)
        let (viewModel, eventsRepository, _) = makeViewModel(
            events: [event(id: "e1", title: "회의", day: date(11, 10))],
            clock: clock
        )
        await viewModel.onAppear()

        clock.now = date(12, 2, hour: 9)
        viewModel.visibleOffset = 1
        await viewModel.waitForWindowLoad()

        // 오프셋 1 = 12월 → 새로 받을 달은 1월뿐(11·12월은 이미 받음).
        #expect(await eventsRepository.fetchedRanges == [
            monthRange(11), monthRange(10), monthRange(12), monthRange(1, year: 2027),
        ])
        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["회의"])
    }

    // MARK: - 적재

    @Test func onAppearLoadsEventsAndRemindersIntoCurrentMonth() async {
        let reminders = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [reminder(id: "r1", title: "장보기", due: date(11, 12, hour: 9))]
        )
        let (viewModel, _, _) = makeViewModel(
            events: [event(id: "e1", title: "회의", day: date(11, 10))],
            remindersRepository: reminders
        )

        await viewModel.onAppear()

        let page = viewModel.page(for: 0)
        #expect(page.items(day: 10).map(\.title) == ["회의"])
        #expect(page.items(day: 12).map(\.title) == ["장보기"])
        #expect(page.items(day: 12).first?.colorHex == "#FF9500")
        #expect(page.items(day: 11).isEmpty)
    }

    /// 인메모리 fetchReminders는 권한을 보지 않는다 — 할일이 비어 있으면 조회 자체를 안 한 것.
    @Test func remindersDeniedShowsEventsOnlyWithoutFetchingReminders() async {
        let reminders = InMemoryRemindersRepository(
            access: .denied, lists: [listA],
            reminders: [reminder(id: "r1", title: "장보기", due: date(11, 12, hour: 9))]
        )
        let (viewModel, _, _) = makeViewModel(
            events: [event(id: "e1", title: "회의", day: date(11, 10))],
            remindersRepository: reminders
        )

        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["회의"])
        #expect(viewModel.page(for: 0).items(day: 12).isEmpty)
    }

    @Test func eventsDeniedSkipsFetchEventsButKeepsReminders() async {
        let reminders = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [reminder(id: "r1", title: "장보기", due: date(11, 12, hour: 9))]
        )
        let (viewModel, eventsRepository, _) = makeViewModel(
            eventsAccess: .denied,
            events: [event(id: "e1", title: "회의", day: date(11, 10))],
            remindersRepository: reminders
        )

        await viewModel.onAppear()

        #expect(await eventsRepository.fetchedRanges.isEmpty)
        #expect(viewModel.page(for: 0).items(day: 10).isEmpty)
        #expect(viewModel.page(for: 0).items(day: 12).map(\.title) == ["장보기"])
    }

    @Test func hiddenCalendarEventsAreExcluded() async {
        var settings = AppSettings.default
        settings.hiddenCalendarIDs = ["cal-hidden"]
        let (viewModel, _, _) = makeViewModel(
            events: [
                event(id: "e1", title: "보임", day: date(11, 10), calendarID: "cal-a"),
                event(id: "e2", title: "숨김", day: date(11, 10), calendarID: "cal-hidden"),
            ],
            appSettings: settings
        )

        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["보임"])
    }

    @Test func isLoadedFlipsOnlyForVisibleMonthAndNeighbors() async {
        let (viewModel, _, _) = makeViewModel()
        #expect(!viewModel.page(for: 0).isLoaded)

        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).isLoaded)
        #expect(viewModel.page(for: -1).isLoaded)
        #expect(viewModel.page(for: 1).isLoaded)
        #expect(!viewModel.page(for: 2).isLoaded)
    }

    @Test func visibleMonthThenNeighborsAreFetchedAndSavedAsSnapshot() async {
        let (viewModel, eventsRepository, cache) = makeViewModel(events: [
            event(id: "e0", title: "시월", day: date(10, 5)),
            event(id: "e1", title: "회의", day: date(11, 10)),
            event(id: "e2", title: "송년회", day: date(12, 5)),
            event(id: "e3", title: "신년", day: date(1, 5, year: 2027)),
        ])

        await viewModel.onAppear()

        #expect(await eventsRepository.fetchedRanges == [monthRange(11), monthRange(10), monthRange(12)])
        #expect(viewModel.page(for: 1).items(day: 5).map(\.title) == ["송년회"])
        #expect(await cache.savedMonthEvents.count == 1)
        let saved = await cache.savedMonthEvents.last
        #expect(saved?.months.keys.sorted() == [date(10, 1), date(11, 1), date(12, 1)])
        #expect(saved?.months[date(12, 1)]?.map(\.title) == ["송년회"])

        // 다음 달로 넘겨 1월을 새로 받아도 스냅샷 대상(이번 달 ±1)은 새로 받은 게 없다 → 저장 안 함.
        viewModel.visibleOffset = 1
        await viewModel.waitForWindowLoad()
        #expect(await cache.savedMonthEvents.count == 1)
    }

    /// 먼 달을 보다 종료해도 다음 실행 첫 페인트(이번 달)가 비지 않게 — 먼 달은 스냅샷에 넣지 않는다.
    @Test func jumpingToFarMonthDoesNotChangeSnapshot() async {
        let (viewModel, eventsRepository, cache) = makeViewModel(events: [
            event(id: "e1", title: "회의", day: date(11, 10)),
            event(id: "e2", title: "여름", day: date(6, 10, year: 2027)),
        ])
        await viewModel.onAppear()
        #expect(await cache.savedMonthEvents.count == 1)

        viewModel.jump(to: date(6, 1, year: 2027))
        await viewModel.waitForWindowLoad()

        #expect(await eventsRepository.fetchedRanges.contains(monthRange(6, year: 2027)))
        #expect(viewModel.page(for: 7).items(day: 10).map(\.title) == ["여름"])
        #expect(await cache.savedMonthEvents.count == 1)
        #expect(await cache.savedMonthEvents.last?.months.keys.sorted() == [date(10, 1), date(11, 1), date(12, 1)])
    }

    /// 먼 달에서 외부 변경으로 재조회돼도 앵커 달이 없으니 저장하지 않는다.
    @Test func externalChangeOnFarMonthDoesNotSaveSnapshot() async throws {
        let reminders = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let (viewModel, _, cache) = makeViewModel(remindersRepository: reminders)
        await viewModel.onAppear()
        viewModel.jump(to: date(6, 1, year: 2027))
        await viewModel.waitForWindowLoad()

        await reminders.emitChange()
        try await waitUntil { viewModel.externalReloadCount >= 1 }

        #expect(await cache.savedMonthEvents.count == 1)
    }

    /// 이번 달에서 외부 변경으로 다시 받으면 갱신된 내용으로 스냅샷을 다시 남긴다.
    @Test func externalChangeOnAnchorMonthSavesSnapshot() async throws {
        let reminders = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let (viewModel, _, cache) = makeViewModel(remindersRepository: reminders)
        await viewModel.onAppear()
        #expect(await cache.savedMonthEvents.count == 1)

        await reminders.emitChange()
        try await waitUntil { viewModel.externalReloadCount >= 1 }

        #expect(await cache.savedMonthEvents.count == 2)
        #expect(await cache.savedMonthEvents.last?.months.keys.sorted() == [date(10, 1), date(11, 1), date(12, 1)])
    }

    /// 진행 중 조회가 실패하면 기다리던 호출자들이 깨어난다 — 그중 하나만 새로 조회하고 나머지는 그걸 기다린다.
    @Test func waitersOfFailedFetchStartOnlyOneRetry() async throws {
        let (viewModel, eventsRepository, _) = makeViewModel()
        await eventsRepository.failNextFetches(1)
        await eventsRepository.closeGate()

        let appear = Task { await viewModel.onAppear() }
        try await waitUntil { await eventsRepository.fetchedRanges.count >= 1 }
        // 첫 11월 조회가 막혀 있는 동안 같은 윈도우 적재를 두 번 더 겹쳐 11월을 기다리게 한다.
        let again = Task { await viewModel.onAppear() }
        let active = Task { await viewModel.sceneDidBecomeActive() }
        try await Task.sleep(nanoseconds: 100_000_000)
        await eventsRepository.openGate()
        await appear.value
        await again.value
        await active.value

        let ranges = await eventsRepository.fetchedRanges
        // 실패 1번 + 재시도 1번. 고치기 전엔 기다리던 둘이 각자 재시도해 11월이 3번 조회됐다.
        #expect(ranges.filter { $0 == monthRange(11) }.count == 2)
        #expect(ranges.count == 4)
        #expect(Set(ranges) == [monthRange(10), monthRange(11), monthRange(12)])
    }

    @Test func alreadyFetchedMonthsAreNotFetchedAgain() async {
        let (viewModel, eventsRepository, _) = makeViewModel()
        await viewModel.onAppear()

        viewModel.visibleOffset = 1
        await viewModel.waitForWindowLoad()
        // 재진입(모드 전환)도 받아 둔 달은 다시 조회하지 않는다.
        await viewModel.onAppear()

        // 11·10·12월은 이미 받았으니 1월만 새로.
        #expect(await eventsRepository.fetchedRanges == [
            monthRange(11), monthRange(10), monthRange(12), monthRange(1, year: 2027),
        ])
    }

    @Test func rapidOffsetChangesFetchOnlyTheLastMonthAndNeighbors() async {
        let (viewModel, eventsRepository, _) = makeViewModel()
        await viewModel.onAppear()

        // 디바운스 중에 연달아 넘기면 앞선 예약은 취소된다 — 지나쳐 간 달(12~3월)은 조회 안 함.
        for offset in 1...5 { viewModel.visibleOffset = offset }
        await viewModel.waitForWindowLoad()

        let ranges = await eventsRepository.fetchedRanges
        let afterSwipe = Array(ranges.dropFirst(3))
        #expect(afterSwipe == [monthRange(4, year: 2027), monthRange(3, year: 2027), monthRange(5, year: 2027)])
    }

    @Test func monthsOutsideWindowAreEvictedAndRefetchedOnRevisit() async {
        let (viewModel, eventsRepository, _) = makeViewModel(
            events: [event(id: "e1", title: "회의", day: date(11, 10))]
        )
        await viewModel.onAppear()
        let november = viewModel.page(for: 0)
        #expect(november.items(day: 10).map(\.title) == ["회의"])

        // 2월로 → 윈도우 12월~4월. 11월·10월은 축출.
        viewModel.visibleOffset = 3
        await viewModel.waitForWindowLoad()

        #expect(!november.isLoaded)
        #expect(november.items(day: 10).isEmpty)
        #expect(viewModel.cachedMonthStarts == [
            date(12, 1), date(1, 1, year: 2027), date(2, 1, year: 2027), date(3, 1, year: 2027),
        ])

        viewModel.visibleOffset = 0
        await viewModel.waitForWindowLoad()

        // 뷰가 붙들고 있던 같은 페이지 객체가 다시 채워진다.
        #expect(viewModel.page(for: 0) === november)
        #expect(november.items(day: 10).map(\.title) == ["회의"])
        let ranges = await eventsRepository.fetchedRanges
        #expect(ranges.filter { $0 == monthRange(11) }.count == 2)
    }

    @Test func remindersAreIndexedByDueMonthAtBoundaries() async {
        let reminders = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [
                reminder(id: "r1", title: "말일", due: date(11, 30, hour: 23, minute: 59)),
                reminder(id: "r2", title: "첫날", due: date(12, 1)),
                reminder(id: "r3", title: "마감 없음", due: nil),
            ]
        )
        let (viewModel, _, _) = makeViewModel(remindersRepository: reminders)

        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).items(day: 30).map(\.title) == ["말일"])
        #expect(viewModel.page(for: 0).items(day: 1).isEmpty)
        #expect(viewModel.page(for: 1).items(day: 1).map(\.title) == ["첫날"])
        #expect(viewModel.page(for: 1).items(day: 31).isEmpty)
    }

    /// 칩 탭 → 시트에 넘길 할일 원본. 다른 달 마감도 찾고, 마감 없는(칩이 없는)·모르는 id는 nil.
    @Test func reminderLookupFindsLoadedRemindersAcrossMonths() async {
        let reminders = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [
                reminder(id: "r1", title: "이번 달", due: date(11, 12, hour: 9)),
                reminder(id: "r2", title: "먼 달", due: date(3, 1, year: 2027)),
                reminder(id: "r3", title: "마감 없음", due: nil),
            ]
        )
        let (viewModel, _, _) = makeViewModel(remindersRepository: reminders)

        await viewModel.onAppear()

        #expect(viewModel.reminder(id: "r1")?.title == "이번 달")
        #expect(viewModel.reminder(id: "r2")?.title == "먼 달")
        #expect(viewModel.reminder(id: "r3") == nil)
        #expect(viewModel.reminder(id: "unknown") == nil)
    }

    // MARK: - 스냅샷 첫 페인트

    @Test func snapshotPaintsBeforeFetchAndFetchReplacesIt() async throws {
        let cache = RecordingSnapshotCache(monthEvents: MonthEventsSnapshot(months: [
            date(11, 1): [event(id: "old", title: "옛 회의", day: date(11, 10))],
        ]))
        let (viewModel, eventsRepository, _) = makeViewModel(
            events: [event(id: "new", title: "새 회의", day: date(11, 10))],
            snapshotCache: cache
        )
        await eventsRepository.closeGate()

        let appear = Task { await viewModel.onAppear() }
        try await waitUntil { await eventsRepository.fetchedRanges.count >= 1 }

        // 조회가 막혀 있는 동안 스냅샷으로 이미 그려져 있다.
        #expect(viewModel.page(for: 0).isLoaded)
        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["옛 회의"])

        await eventsRepository.openGate()
        await appear.value

        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["새 회의"])
    }

    @Test func eventsDeniedIgnoresMonthSnapshot() async {
        let cache = RecordingSnapshotCache(monthEvents: MonthEventsSnapshot(months: [
            date(11, 1): [event(id: "old", title: "옛 회의", day: date(11, 10))],
        ]))
        let (viewModel, _, _) = makeViewModel(eventsAccess: .denied, snapshotCache: cache)

        await viewModel.onAppear()

        #expect(await cache.monthEventsLoadCount == 0)
        #expect(await cache.savedMonthEvents.isEmpty)
        #expect(viewModel.page(for: 0).items(day: 10).isEmpty)
    }

    // MARK: - 포그라운드 복귀

    @Test func becomingActiveAfterGrantRefetchesWindowMonths() async {
        let (viewModel, eventsRepository, cache) = makeViewModel(
            eventsAccess: .denied,
            events: [event(id: "e1", title: "회의", day: date(11, 10))]
        )
        await viewModel.onAppear()
        #expect(await eventsRepository.fetchedRanges.isEmpty)
        #expect(viewModel.page(for: 0).items(day: 10).isEmpty)

        // 설정 앱에서 캘린더 권한을 켜고 돌아온다.
        await eventsRepository.setAccess(.granted)
        await viewModel.sceneDidBecomeActive()

        #expect(await eventsRepository.fetchedRanges == [monthRange(11), monthRange(10), monthRange(12)])
        #expect(viewModel.page(for: 0).items(day: 10).map(\.title) == ["회의"])
        #expect(await cache.savedMonthEvents.last?.months.keys.sorted() == [date(10, 1), date(11, 1), date(12, 1)])
    }

    @Test func becomingActiveWithoutChangesDoesNotRefetchEvents() async {
        let (viewModel, eventsRepository, cache) = makeViewModel()
        await viewModel.onAppear()

        await viewModel.sceneDidBecomeActive()

        #expect(await eventsRepository.fetchedRanges.count == 3)
        #expect(await cache.savedMonthEvents.count == 1)
    }

    @Test func becomingActiveOnNewDayRefreshesToday() async {
        let clock = MutableClock(now)
        let (viewModel, eventsRepository, _) = makeViewModel(clock: clock)
        await viewModel.onAppear()
        let page = viewModel.page(for: 0)
        #expect(page.grid.isToday(day: 15))

        clock.now = date(11, 16, hour: 8)
        await viewModel.sceneDidBecomeActive()

        #expect(page.grid.isToday(day: 16))
        #expect(!page.grid.isToday(day: 15))
        #expect(await eventsRepository.fetchedRanges.count == 3)
    }

    // MARK: - 완료한 할일 표시 설정

    private func completedAndOpenReminders() -> InMemoryRemindersRepository {
        InMemoryRemindersRepository(access: .granted, lists: [listA], reminders: [
            Reminder(id: "done", title: "끝낸 일", isCompleted: true, notes: nil,
                     dueDate: date(11, 20, hour: 9), includesTime: true, listID: listA.id),
            Reminder(id: "open", title: "남은 일", isCompleted: false, notes: nil,
                     dueDate: date(11, 20, hour: 10), includesTime: true, listID: listA.id),
        ])
    }

    /// 기본은 완료한 할일도 칸에 보인다(설정이 없던 시절 동작).
    @Test func completedRemindersShownByDefault() async {
        let (viewModel, _, _) = makeViewModel(remindersRepository: completedAndOpenReminders())
        await viewModel.onAppear()

        #expect(Set(viewModel.page(for: 0).items(day: 20).map(\.title)) == ["끝낸 일", "남은 일"])
    }

    /// 설정을 끄면 완료한 할일은 빠지고 남은 할일만 보인다.
    @Test func completedRemindersHiddenWhenSettingOff() async {
        var settings = AppSettings.default
        settings.monthShowsCompletedReminders = false
        let (viewModel, _, _) = makeViewModel(
            remindersRepository: completedAndOpenReminders(), appSettings: settings
        )
        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).items(day: 20).map(\.title) == ["남은 일"])
    }

    // MARK: - 날씨

    /// 오늘(15일)부터 이틀치 예보 — 16일은 다음 날.
    private func twoDayForecast() -> [DailyWeather] {
        [
            DailyWeather(date: date(11, 15), symbolName: "cloud.rain"),
            DailyWeather(date: date(11, 16), symbolName: "sun.max"),
        ]
    }

    private func weatherSettings(on: Bool) -> AppSettings {
        var settings = AppSettings.default
        settings.monthShowsWeather = on
        return settings
    }

    /// 설정이 켜져 있으면 예보가 있는 날 칸에 날씨 아이콘 이름이 붙고, 예보 없는 날은 nil.
    @Test func weatherShownOnForecastDaysWhenSettingOn() async {
        let weather = InMemoryWeatherRepository(forecast: twoDayForecast())
        let (viewModel, _, _) = makeViewModel(appSettings: weatherSettings(on: true), weather: weather)
        await viewModel.onAppear()
        await viewModel.waitForWeather()

        let page = viewModel.page(for: 0)
        #expect(page.weatherSymbol(day: 15) == "cloud.rain")
        #expect(page.weatherSymbol(day: 16) == "sun.max")
        #expect(page.weatherSymbol(day: 17) == nil)
        // 다른 달 페이지엔 이번 달 날씨가 새지 않는다.
        #expect(viewModel.page(for: 1).weatherSymbol(day: 15) == nil)
    }

    /// 설정이 꺼져 있으면 예보를 조회하지도, 그리지도 않는다.
    @Test func weatherNotFetchedWhenSettingOff() async {
        let weather = InMemoryWeatherRepository(forecast: twoDayForecast())
        let (viewModel, _, _) = makeViewModel(weather: weather)
        await viewModel.onAppear()
        await viewModel.waitForWeather()

        #expect(await weather.forecastFetchCount == 0)
        #expect(viewModel.page(for: 0).weatherSymbol(day: 15) == nil)
    }

    /// 조회가 실패하면 아이콘 없이 그린다 — 일정·할일 표시는 영향 없다.
    @Test func weatherFailureLeavesDaysWithoutIcons() async {
        let weather = InMemoryWeatherRepository(forecast: twoDayForecast(), fails: true)
        let (viewModel, _, _) = makeViewModel(
            events: [event(id: "e1", title: "회의", day: date(11, 15))],
            appSettings: weatherSettings(on: true), weather: weather
        )
        await viewModel.onAppear()
        await viewModel.waitForWeather()

        let page = viewModel.page(for: 0)
        #expect(page.weatherSymbol(day: 15) == nil)
        #expect(page.items(day: 15).map(\.title) == ["회의"])
    }

    /// 켜져 있던 설정을 끄고 다시 나타나면(설정 탭 → 일정 탭) 아이콘이 사라진다.
    @Test func weatherClearedWhenSettingTurnedOff() async {
        let settings = InMemoryAppSettingsRepository(storage: weatherSettings(on: true))
        let weather = InMemoryWeatherRepository(forecast: twoDayForecast())
        var dependencies = Dependencies.preview
        dependencies.currentEventsAccess = CurrentEventsAccessUseCase(repository: InMemoryEventsRepository())
        dependencies.fetchEvents = FetchEventsUseCase(repository: InMemoryEventsRepository())
        dependencies.fetchAppSettings = FetchAppSettingsUseCase(repository: settings)
        dependencies.fetchDailyWeather = FetchDailyWeatherUseCase(repository: weather)
        let fixedNow = now
        let viewModel = ScheduleMonthViewModel(dependencies: dependencies, now: { fixedNow }, debounce: .zero)
        await viewModel.onAppear()
        await viewModel.waitForWeather()
        #expect(viewModel.page(for: 0).weatherSymbol(day: 15) == "cloud.rain")

        var off = await settings.fetch()
        off.monthShowsWeather = false
        await settings.save(off)
        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).weatherSymbol(day: 15) == nil)
    }

    // MARK: - 음력

    private func lunarSettings(on: Bool) -> AppSettings {
        var settings = AppSettings.default
        settings.monthShowsLunarDate = on
        return settings
    }

    /// 설정이 켜져 있고 한국 지역이면 칸마다 그 날의 음력 표기가 붙는다(달마다 제 날짜로).
    @Test func lunarShownWhenSettingOnAndAvailable() async {
        let (viewModel, _, _) = makeViewModel(appSettings: lunarSettings(on: true), isLunarDateAvailable: true)
        await viewModel.onAppear()

        let page = viewModel.page(for: 0)
        #expect(page.lunarLabel(day: 22) == "10.14")
        #expect(page.lunarLabel(day: 9) == "10.1")
        #expect(viewModel.page(for: 1).lunarLabel(day: 22) == "11.14")
    }

    /// 설정이 켜져 있어도 한국 지역이 아니면 그리지 않는다(설정 화면에서 토글이 숨겨진 뒤 남은 값).
    @Test func lunarNotShownWhenUnavailableEvenIfSettingOn() async {
        let (viewModel, _, _) = makeViewModel(appSettings: lunarSettings(on: true), isLunarDateAvailable: false)
        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).lunarLabel(day: 22) == nil)
    }

    /// 한국 지역이어도 기본(설정 꺼짐)은 그리지 않는다.
    @Test func lunarNotShownWhenSettingOff() async {
        let (viewModel, _, _) = makeViewModel(isLunarDateAvailable: true)
        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).lunarLabel(day: 22) == nil)
    }

    /// 켜져 있던 설정을 끄고 다시 나타나면(설정 탭 → 일정 탭) 음력 표기가 사라진다.
    @Test func lunarClearedWhenSettingTurnedOff() async {
        let settings = InMemoryAppSettingsRepository(storage: lunarSettings(on: true))
        var dependencies = Dependencies.preview
        dependencies.currentEventsAccess = CurrentEventsAccessUseCase(repository: InMemoryEventsRepository())
        dependencies.fetchEvents = FetchEventsUseCase(repository: InMemoryEventsRepository())
        dependencies.fetchAppSettings = FetchAppSettingsUseCase(repository: settings)
        dependencies.isLunarDateAvailable = true
        let fixedNow = now
        let viewModel = ScheduleMonthViewModel(dependencies: dependencies, now: { fixedNow }, debounce: .zero)
        await viewModel.onAppear()
        #expect(viewModel.page(for: 0).lunarLabel(day: 22) == "10.14")

        var off = await settings.fetch()
        off.monthShowsLunarDate = false
        await settings.save(off)
        await viewModel.onAppear()

        #expect(viewModel.page(for: 0).lunarLabel(day: 22) == nil)
    }

    // MARK: - 외부 변경

    @Test func externalChangeReloadsRemindersAndWindowMonths() async throws {
        let reminders = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let (viewModel, eventsRepository, _) = makeViewModel(remindersRepository: reminders)
        await viewModel.onAppear()
        #expect(await eventsRepository.fetchedRanges.count == 3)

        // 외부(미리 알림 앱) 추가 후 변경 신호.
        try await reminders.addReminder(
            title: "새 할일", notes: nil, dueDate: date(11, 20, hour: 9),
            includesTime: true, recurrence: nil, toListID: listA.id
        )
        await reminders.emitChange()
        try await waitUntil { viewModel.externalReloadCount >= 1 }

        #expect(viewModel.page(for: 0).items(day: 20).map(\.title) == ["새 할일"])
        #expect(await eventsRepository.fetchedRanges.count == 6)
    }

    /// 앱이 직접 쓴 뒤엔 변경 알림 없이도 다시 읽는다 — EventKit이 알림을 빠뜨리는 경우(QA N-07).
    @Test func reloadAfterOwnWriteShowsEventWithoutChangeSignal() async {
        let (viewModel, eventsRepository, _) = makeViewModel()
        await viewModel.onAppear()

        await eventsRepository.insertSilently(event(id: "new", title: "새 일정", day: date(11, 20)))
        await viewModel.reloadAfterOwnWrite()

        #expect(viewModel.page(for: 0).items(day: 20).map(\.title) == ["새 일정"])
        #expect(viewModel.externalReloadCount == 1)
    }

    /// 월 모드를 한 번도 안 열었으면 건너뛴다 — 처음 열 때 onAppear가 읽는다.
    @Test func reloadAfterOwnWriteBeforeAppearDoesNothing() async {
        let (viewModel, eventsRepository, _) = makeViewModel()

        await viewModel.reloadAfterOwnWrite()

        #expect(await eventsRepository.fetchedRanges.isEmpty)
        #expect(viewModel.externalReloadCount == 0)
    }

    @Test func externalChangeRefetchesOnlyWindowMonths() async throws {
        let reminders = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let (viewModel, eventsRepository, _) = makeViewModel(remindersRepository: reminders)
        await viewModel.onAppear()
        // 2월로 → 받아 둔 달 12월~3월(10·11월은 축출).
        viewModel.visibleOffset = 3
        await viewModel.waitForWindowLoad()
        let before = await eventsRepository.fetchedRanges.count

        await reminders.emitChange()
        try await waitUntil { viewModel.externalReloadCount >= 1 }

        let ranges = await eventsRepository.fetchedRanges
        let refetched = Array(ranges.dropFirst(before))
        #expect(refetched.count == 4)
        #expect(Set(refetched.map(\.start)) == [
            date(12, 1), date(1, 1, year: 2027), date(2, 1, year: 2027), date(3, 1, year: 2027),
        ])
    }
}

/// 바꿀 수 있는 현재 시각 — 앱을 켜 둔 채 날·달이 바뀌는 상황용. 테스트·VM 모두 메인 액터에서만 쓴다.
private final class MutableClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

/// 일정 조회 범위를 기록하는 리포지토리 더블 — 나머지는 InMemory에 위임한다.
/// 게이트를 닫으면 조회가 열릴 때까지 멈춘다(스냅샷이 조회 전에 보이는지 확인용).
private actor RecordingEventsRepository: EventsRepository {
    private let base: InMemoryEventsRepository
    private(set) var fetchedRanges: [DateInterval] = []
    private var isGated = false
    /// 앱 밖(설정 앱)에서 바뀐 권한 — 설정되면 base 대신 돌려준다.
    private var accessOverride: EventsAccess?
    /// 남은 실패 횟수 — 게이트를 지난 조회가 이 횟수만큼 던진다.
    private var failuresRemaining = 0

    init(_ base: InMemoryEventsRepository) { self.base = base }

    func closeGate() { isGated = true }
    func openGate() { isGated = false }
    func setAccess(_ access: EventsAccess) { accessOverride = access }
    func failNextFetches(_ count: Int) { failuresRemaining = count }

    func requestAccess() async -> EventsAccess { await base.requestAccess() }
    func currentAccess() async -> EventsAccess {
        if let accessOverride { return accessOverride }
        return await base.currentAccess()
    }
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        fetchedRanges.append(DateInterval(start: from, end: to))
        while isGated { try await Task.sleep(nanoseconds: 1_000_000) }
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw RecordingFetchError()
        }
        return try await base.fetchEvents(from: from, to: to)
    }
    func fetchCalendars() async throws -> [EventCalendar] { try await base.fetchCalendars() }
    nonisolated func changes() -> AsyncStream<Void> { base.changes() }
    func insertSilently(_ event: CalendarEvent) async { await base.insertSilently(event) }
}

private struct RecordingFetchError: Error {}

/// 스냅샷 캐시 더블 — 월 일정 스냅샷을 읽은 횟수와 저장 내역을 기록한다.
private actor RecordingSnapshotCache: SnapshotCacheRepository {
    private var monthEvents: MonthEventsSnapshot?
    private var reminders: RemindersSnapshot?
    private(set) var monthEventsLoadCount = 0
    private(set) var savedMonthEvents: [MonthEventsSnapshot] = []

    init(monthEvents: MonthEventsSnapshot? = nil, reminders: RemindersSnapshot? = nil) {
        self.monthEvents = monthEvents
        self.reminders = reminders
    }

    func loadRemindersSnapshot() async -> RemindersSnapshot? { reminders }
    func saveRemindersSnapshot(_ snapshot: RemindersSnapshot) async { reminders = snapshot }
    func loadEventsSnapshot() async -> EventsSnapshot? { nil }
    func saveEventsSnapshot(_ snapshot: EventsSnapshot) async {}
    func loadMonthEventsSnapshot() async -> MonthEventsSnapshot? {
        monthEventsLoadCount += 1
        return monthEvents
    }
    func saveMonthEventsSnapshot(_ snapshot: MonthEventsSnapshot) async {
        monthEvents = snapshot
        savedMonthEvents.append(snapshot)
    }
}
