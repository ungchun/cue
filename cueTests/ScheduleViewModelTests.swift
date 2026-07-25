//
//  ScheduleViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ScheduleViewModelTests {

    /// 인메모리 fake로 일정 탭 의존성을 조립한다.
    /// 미리알림·아이템 UseCase는 일정 탭에 쓰이지 않지만 `Dependencies` 묶음이 요구하므로
    /// 채워둔다.
    private func makeDependencies(
        access: EventsAccess = .granted,
        events: [CalendarEvent] = [],
        calendars: [EventCalendar] = [],
        appSettings: AppSettings = .default,
        eventsRepository injected: (any EventsRepository)? = nil,
        analytics: SpyAnalyticsService? = nil
    ) -> Dependencies {
        let eventsRepository = injected ?? InMemoryEventsRepository(
            access: access, events: events, calendars: calendars
        )
        let remindersRepository = InMemoryRemindersRepository(access: .granted)
        let reminderSortRepository = InMemoryReminderSortRepository()
        let itemRepository = InMemoryItemRepository()
        let focusSessionsRepository = InMemoryFocusSessionsRepository()
        var dependencies = Dependencies(
            fetchItems: FetchItemsUseCase(repository: itemRepository),
            addItem: AddItemUseCase(repository: itemRepository),
            deleteItem: DeleteItemUseCase(repository: itemRepository),
            requestRemindersAccess: RequestRemindersAccessUseCase(repository: remindersRepository),
            fetchReminderLists: FetchReminderListsUseCase(repository: remindersRepository),
            fetchReminders: FetchRemindersUseCase(repository: remindersRepository),
            toggleReminderCompletion: ToggleReminderCompletionUseCase(repository: remindersRepository),
            addReminder: AddReminderUseCase(repository: remindersRepository),
            updateReminder: UpdateReminderUseCase(repository: remindersRepository),
            deleteReminder: DeleteReminderUseCase(repository: remindersRepository),
            addReminderList: AddReminderListUseCase(repository: remindersRepository),
            updateReminderList: UpdateReminderListUseCase(repository: remindersRepository),
            deleteReminderList: DeleteReminderListUseCase(repository: remindersRepository),
            observeRemindersChanges: ObserveRemindersChangesUseCase(repository: remindersRepository),
            fetchReminderSortSettings: FetchReminderSortSettingsUseCase(repository: reminderSortRepository),
            saveReminderSortSettings: SaveReminderSortSettingsUseCase(repository: reminderSortRepository),
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository),
            fetchCalendars: FetchCalendarsUseCase(repository: eventsRepository),
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepository),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            fetchMemo: FetchMemoUseCase(repository: InMemoryMemoRepository()),
            saveMemo: SaveMemoUseCase(repository: InMemoryMemoRepository()),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService()),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: DisabledLiveActivityService()),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: DisabledAppUpdatePolicyService()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: InMemoryAppSettingsRepository(storage: appSettings)),
            saveAppSettings: SaveAppSettingsUseCase(repository: InMemoryAppSettingsRepository(storage: appSettings))
        )
        // 프리페치의 프롬프트-없는 권한 조회도 같은 repo를 보게 배선 — 기본값(별도 인메모리)은
        // 항상 미결정이라 프리페치가 무조건 건너뛰게 된다.
        dependencies.currentEventsAccess = CurrentEventsAccessUseCase(repository: eventsRepository)
        if let analytics { dependencies.analytics = analytics }
        return dependencies
    }

    @Test func initialStateHasNoAccessAndSheetClosed() {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(access: .notDetermined))

        #expect(viewModel.access == .notDetermined)
        #expect(viewModel.showingNewEvent == false)
    }

    @Test func onAppearGrantsAccessWhenNotDetermined() async {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(access: .notDetermined))

        await viewModel.onAppear()

        #expect(viewModel.access == .granted)
    }

    @Test func onAppearKeepsDeniedAccess() async {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(access: .denied))

        await viewModel.onAppear()

        #expect(viewModel.access == .denied)
    }

    @Test func presentNewEventOpensSheet() {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies())

        viewModel.presentNewEvent()

        #expect(viewModel.showingNewEvent == true)
    }

    @Test func dismissNewEventClosesSheet() {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies())
        viewModel.presentNewEvent()

        viewModel.dismissNewEvent()

        #expect(viewModel.showingNewEvent == false)
    }

    // MARK: - 이벤트 로드 + 날짜별 그룹핑

    private func event(
        id: String,
        title: String = "이벤트",
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        isReadOnly: Bool = false,
        calendarID: String = ""
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title,
            startDate: start, endDate: end,
            isAllDay: isAllDay, calendarColorHex: nil,
            isReadOnly: isReadOnly, calendarID: calendarID
        )
    }

    @Test func onAppearLoadsEventsAfterGrant() async {
        let today = Calendar.current.startOfDay(for: Date())
        let event1 = event(id: "1", start: today.addingTimeInterval(60 * 60), end: today.addingTimeInterval(2 * 60 * 60))
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [event1]), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.count == 1)
        #expect(viewModel.eventsByDay.first?.events.map(\.id) == ["1"])
    }

    /// 설정에서 숨긴 캘린더의 이벤트는 타임라인에서 제외된다.
    @Test func hiddenCalendarEventsAreExcluded() async {
        let today = Calendar.current.startOfDay(for: Date())
        var settings = AppSettings.default
        settings.hiddenCalendarIDs = ["work"]
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(
            events: [
                event(id: "p", start: today.addingTimeInterval(60 * 60), end: today.addingTimeInterval(2 * 60 * 60), calendarID: "personal"),
                event(id: "w", start: today.addingTimeInterval(3 * 60 * 60), end: today.addingTimeInterval(4 * 60 * 60), calendarID: "work"),
            ],
            appSettings: settings
        ), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["p"])
    }

    /// 숨긴 캘린더가 없으면 모든 이벤트가 보인다(기본).
    @Test func noHiddenCalendarsShowsAllEvents() async {
        let today = Calendar.current.startOfDay(for: Date())
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(
            events: [
                event(id: "p", start: today.addingTimeInterval(60 * 60), end: today.addingTimeInterval(2 * 60 * 60), calendarID: "personal"),
                event(id: "w", start: today.addingTimeInterval(3 * 60 * 60), end: today.addingTimeInterval(4 * 60 * 60), calendarID: "work"),
            ]
        ), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id).sorted() == ["p", "w"])
    }

    /// Premium(무제한)이면 켜기 버튼이 `.unlimited`로 그대로 LA를 켠다 — 설정 "라이브 항상 표시"와 무관.
    /// 시간대 의존을 피하려 오늘 종일 이벤트를 쓴다(use case가 실제 `.now` 기준으로 필터해도 포함).
    @Test func togglePremiumUserStartsScheduleLiveActivity() async {
        let today = Calendar.current.startOfDay(for: Date())
        let allDay = event(id: "allday", start: today, end: today.addingTimeInterval(24 * 60 * 60), isAllDay: true)
        let viewModel = ScheduleViewModel(
            dependencies: makeDependencies(events: [allDay]),
            premiumStore: PremiumStore(previewIsPremium: true),
            now: { today }
        )
        await viewModel.onAppear()

        let verdict = await viewModel.toggleLiveActivity()

        #expect(verdict == .unlimited)
        #expect(viewModel.liveActivityActive == true)
    }

    /// 항상 표시 자동 게시(Premium 전용) — 권한·데이터가 있으면 쿼터 소비 없이 LA를 시작한다.
    @Test func alwaysOnStartsWhenPremium() async {
        let today = Calendar.current.startOfDay(for: Date())
        let allDay = event(id: "allday", start: today, end: today.addingTimeInterval(24 * 60 * 60), isAllDay: true)
        let viewModel = ScheduleViewModel(
            dependencies: makeDependencies(events: [allDay]),
            premiumStore: PremiumStore(previewIsPremium: true),
            now: { today }
        )

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == true)
    }

    /// 항상 표시는 Premium 전용 — 무료(구독 만료 포함)는 저장값이 켜져 있어도 자동 게시하지 않는다.
    @Test func alwaysOnSkipsWhenNotPremium() async {
        let today = Calendar.current.startOfDay(for: Date())
        let allDay = event(id: "allday", start: today, end: today.addingTimeInterval(24 * 60 * 60), isAllDay: true)
        let viewModel = ScheduleViewModel(
            dependencies: makeDependencies(events: [allDay]),
            now: { today }
        )

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == false)
    }

    @Test func eventsByDayGroupsByCalendarDay() async {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = today.addingTimeInterval(24 * 60 * 60)
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [
            event(id: "a", start: today.addingTimeInterval(10 * 60 * 60), end: today.addingTimeInterval(11 * 60 * 60)),
            event(id: "b", start: today.addingTimeInterval(14 * 60 * 60), end: today.addingTimeInterval(15 * 60 * 60)),
            event(id: "c", start: tomorrow.addingTimeInterval(9 * 60 * 60), end: tomorrow.addingTimeInterval(10 * 60 * 60)),
        ]), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.count == 2)
        #expect(viewModel.eventsByDay[0].date == today)
        #expect(viewModel.eventsByDay[0].events.map(\.id) == ["a", "b"])
        #expect(viewModel.eventsByDay[1].date == tomorrow)
        #expect(viewModel.eventsByDay[1].events.map(\.id) == ["c"])
    }

    @Test func eventsByDaySortsEventsWithinDayByStartTime() async {
        let today = Calendar.current.startOfDay(for: Date())
        let later = event(id: "later", start: today.addingTimeInterval(15 * 60 * 60), end: today.addingTimeInterval(16 * 60 * 60))
        let earlier = event(id: "earlier", start: today.addingTimeInterval(9 * 60 * 60), end: today.addingTimeInterval(10 * 60 * 60))
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [later, earlier]), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.first?.events.map(\.id) == ["earlier", "later"])
    }

    @Test func eventsByDaySkipsDaysWithoutEvents() async {
        // 오늘 + 모레만 이벤트가 있고 내일은 없을 때 — 그룹에 내일이 들어가지 않는다.
        let today = Calendar.current.startOfDay(for: Date())
        let dayAfter = today.addingTimeInterval(2 * 24 * 60 * 60)
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [
            event(id: "today", start: today.addingTimeInterval(10 * 60 * 60), end: today.addingTimeInterval(11 * 60 * 60)),
            event(id: "dayAfter", start: dayAfter.addingTimeInterval(10 * 60 * 60), end: dayAfter.addingTimeInterval(11 * 60 * 60)),
        ]), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.map(\.date) == [today, dayAfter])
    }

    // MARK: - 진행 중 멀티데이 일정 (과거 시작일 → 오늘 그룹으로 클램프)

    @Test func ongoingMultiDayEventGroupsUnderTodayNotItsStartDay() async {
        // 16~20일처럼 과거에 시작해 오늘도 진행 중인 일정은, 시작일(과거) 헤더가 아니라
        // 오늘 그룹에 묶여야 한다 — 지난 날짜 헤더가 뜨지 않도록.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let endsInTwoDays = cal.date(byAdding: .day, value: 2, to: today)!
        let ongoing = event(id: "ongoing", start: twoDaysAgo, end: endsInTwoDays, isAllDay: true)
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [ongoing]))

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.map(\.date) == [today])
        #expect(viewModel.eventsByDay.first?.events.map(\.id) == ["ongoing"])
    }

    @Test func todayAndFutureEventsKeepTheirOwnDayAfterClamp() async {
        // 클램프는 과거 시작일만 끌어올린다 — 오늘·미래 시작 일정은 자기 날짜 그대로.
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [
            event(id: "today", start: today.addingTimeInterval(10 * 60 * 60), end: today.addingTimeInterval(11 * 60 * 60)),
            event(id: "tomorrow", start: tomorrow.addingTimeInterval(10 * 60 * 60), end: tomorrow.addingTimeInterval(11 * 60 * 60)),
        ]), now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.map(\.date) == [today, tomorrow])
    }

    @Test func endedTimedEventsHiddenButOngoingAndAllDayKept() async {
        // 현재 시각 정오 기준 — 오전에 끝난 시간 일정은 오늘이라도 숨기고,
        // 진행 중 시간 일정과 종일 일정은 유지한다(LA와 동일 기준).
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let noon = today.addingTimeInterval(12 * 60 * 60)
        let ended = event(id: "ended", start: today.addingTimeInterval(9 * 60 * 60), end: today.addingTimeInterval(10 * 60 * 60))
        let ongoing = event(id: "ongoing", start: today.addingTimeInterval(11 * 60 * 60), end: today.addingTimeInterval(14 * 60 * 60))
        let allDay = event(id: "allday", start: today, end: today.addingTimeInterval(24 * 60 * 60), isAllDay: true)
        let viewModel = ScheduleViewModel(
            dependencies: makeDependencies(events: [ended, ongoing, allDay]),
            now: { noon }
        )

        await viewModel.onAppear()

        let ids = Set(viewModel.eventsByDay.flatMap(\.events).map(\.id))
        #expect(!ids.contains("ended"))     // 오전에 끝남 → 숨김
        #expect(ids.contains("ongoing"))    // 진행 중 → 유지
        #expect(ids.contains("allday"))     // 종일 → 유지
    }

    @Test func presentEditSetsEditingEvent() {
        let today = Calendar.current.startOfDay(for: Date())
        let target = event(id: "edit-me", start: today, end: today.addingTimeInterval(60 * 60))
        let viewModel = ScheduleViewModel(dependencies: makeDependencies())

        viewModel.presentEdit(target)

        #expect(viewModel.editingEvent?.id == "edit-me")
    }

    @Test func dismissEditClearsEditingEvent() {
        let today = Calendar.current.startOfDay(for: Date())
        let target = event(id: "edit-me", start: today, end: today.addingTimeInterval(60 * 60))
        let viewModel = ScheduleViewModel(dependencies: makeDependencies())
        viewModel.presentEdit(target)

        viewModel.dismissEdit()

        #expect(viewModel.editingEvent == nil)
    }

    // MARK: - 분석 (event_created / event_updated / event_deleted / 외부 열기)

    /// 신규 시트 저장 → `.eventCreated` 1회 — 콜백 구조 변경(outcome) 후에도 기존 로깅 보존.
    @Test func dismissNewEventSavedLogsEventCreated() {
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))
        viewModel.presentNewEvent()

        viewModel.dismissNewEvent(outcome: .saved)

        #expect(analytics.events == [.eventCreated])
        #expect(viewModel.showingNewEvent == false)
    }

    /// 신규 시트 취소 → 아무것도 로깅하지 않는다.
    @Test func dismissNewEventCanceledLogsNothing() {
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))
        viewModel.presentNewEvent()

        viewModel.dismissNewEvent()

        #expect(analytics.events.isEmpty)
    }

    /// 편집 시트 저장 → `.eventUpdated` 1회 + 시트 닫힘.
    @Test func dismissEditSavedLogsEventUpdated() {
        let today = Calendar.current.startOfDay(for: Date())
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))
        viewModel.presentEdit(event(id: "e", start: today, end: today.addingTimeInterval(60 * 60)))

        viewModel.dismissEdit(outcome: .saved)

        #expect(analytics.events == [.eventUpdated])
        #expect(viewModel.editingEvent == nil)
    }

    /// 편집 시트 안 삭제 버튼 → `.eventDeleted` 1회 — `.saved`가 아니라고 취소로 뭉개지지 않는다.
    @Test func dismissEditDeletedLogsEventDeleted() {
        let today = Calendar.current.startOfDay(for: Date())
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))
        viewModel.presentEdit(event(id: "e", start: today, end: today.addingTimeInterval(60 * 60)))

        viewModel.dismissEdit(outcome: .deleted)

        #expect(analytics.events == [.eventDeleted])
        #expect(viewModel.editingEvent == nil)
    }

    /// 편집 시트 취소 → 아무것도 로깅하지 않는다.
    @Test func dismissEditCanceledLogsNothing() {
        let today = Calendar.current.startOfDay(for: Date())
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))
        viewModel.presentEdit(event(id: "e", start: today, end: today.addingTimeInterval(60 * 60)))

        viewModel.dismissEdit()

        #expect(analytics.events.isEmpty)
    }

    /// 좌상단 캘린더 버튼 — Apple 캘린더 앱 열기를 기록한다.
    @Test func calendarAppOpenedLogsExternalAppOpened() {
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(analytics: analytics))

        viewModel.calendarAppOpened()

        #expect(analytics.events == [.externalAppOpened(app: "calendar")])
    }

    /// 권한 거부 화면 "설정 열기" — 설정 앱 이동을 기록한다.
    @Test func permissionSettingsOpenedLogsWithScheduleKind() {
        let analytics = SpyAnalyticsService()
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(access: .denied, analytics: analytics))

        viewModel.permissionSettingsOpened()

        #expect(analytics.events == [.permissionSettingsOpened(kind: "schedule")])
    }

    @Test func loadMoreFetchesEventsInExtendedRange() async {
        // initial 30일 이후 35일 후 시점의 이벤트 — initial fetch엔 안 들어오고
        // loadMore(+14일 추가)에서 들어와야 한다.
        let today = Calendar.current.startOfDay(for: Date())
        let dayInInitial = today.addingTimeInterval(5 * 24 * 60 * 60)
        let dayInExtended = today.addingTimeInterval(35 * 24 * 60 * 60)
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [
            event(id: "in-initial",
                  start: dayInInitial.addingTimeInterval(60 * 60),
                  end: dayInInitial.addingTimeInterval(2 * 60 * 60)),
            event(id: "in-extended",
                  start: dayInExtended.addingTimeInterval(60 * 60),
                  end: dayInExtended.addingTimeInterval(2 * 60 * 60)),
        ]))
        await viewModel.onAppear()
        let initialIDs = Set(viewModel.eventsByDay.flatMap(\.events).map(\.id))
        #expect(initialIDs == ["in-initial"])

        await viewModel.loadMore()

        let afterIDs = Set(viewModel.eventsByDay.flatMap(\.events).map(\.id))
        #expect(afterIDs == ["in-initial", "in-extended"])
    }

    @Test func loadMoreDoesNothingWhenAccessDenied() async {
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(access: .denied))
        await viewModel.onAppear()

        await viewModel.loadMore()

        #expect(viewModel.eventsByDay.isEmpty)
    }

    @Test func loadMorePreservesExistingEventsWithoutDuplicates() async {
        let today = Calendar.current.startOfDay(for: Date())
        let existing = event(id: "existing",
                              start: today.addingTimeInterval(10 * 60 * 60),
                              end: today.addingTimeInterval(11 * 60 * 60))
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [existing]), now: { today })
        await viewModel.onAppear()

        await viewModel.loadMore()

        // existing은 initial 범위에만 있고 extended 범위엔 없음 → 그대로 1건 유지.
        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["existing"])
    }

    @Test func presentEditIgnoresReadOnlyEvent() {
        // 구독 캘린더의 공휴일 같은 read-only 이벤트는 탭해도 시트가 안 떠야 한다.
        let today = Calendar.current.startOfDay(for: Date())
        let holiday = event(
            id: "holiday",
            start: today,
            end: today.addingTimeInterval(24 * 60 * 60),
            isAllDay: true,
            isReadOnly: true
        )
        let viewModel = ScheduleViewModel(dependencies: makeDependencies())

        viewModel.presentEdit(holiday)

        #expect(viewModel.editingEvent == nil)
    }

    @Test func onAppearDoesNotLoadEventsWhenDenied() async {
        let today = Calendar.current.startOfDay(for: Date())
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(
            access: .denied,
            events: [event(id: "1", start: today, end: today.addingTimeInterval(60 * 60))]
        ))

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.isEmpty)
    }

    // MARK: - 스냅샷 캐시 + 프리페치

    /// 캐시가 유효하면(fetchedUntil이 미래) fetch를 기다리지 않고 즉시 페인트한다.
    /// 조용한 최신화가 끝나면 fetch 결과로 대체된다.
    @Test func cachedSnapshotPaintsImmediatelyBeforeFetchCompletes() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let cachedEvent = event(id: "cached",
                                start: today.addingTimeInterval(10 * 60 * 60),
                                end: today.addingTimeInterval(11 * 60 * 60))
        let freshEvent = event(id: "fresh",
                               start: today.addingTimeInterval(12 * 60 * 60),
                               end: today.addingTimeInterval(13 * 60 * 60))
        let cachedUntil = today.addingTimeInterval(7 * 24 * 60 * 60)
        let cache = InMemorySnapshotCacheRepository(
            eventsSnapshot: EventsSnapshot(events: [cachedEvent], fetchedUntil: cachedUntil)
        )
        let base = InMemoryEventsRepository(access: .granted, events: [freshEvent])
        let repo = GatedEventsRepository(base)
        await repo.closeGate()   // 조용한 최신화 fetch를 붙잡아 "캐시만 그려진" 순간을 관측.
        var deps = makeDependencies(eventsRepository: repo)
        deps.loadEventsSnapshot = LoadEventsSnapshotUseCase(repository: cache)
        deps.saveEventsSnapshot = SaveEventsSnapshotUseCase(repository: cache)
        let viewModel = ScheduleViewModel(dependencies: deps, now: { today })

        let appearTask = Task { await viewModel.onAppear() }
        var painted = false
        for _ in 0..<200 {
            if viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["cached"] { painted = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(painted)
        #expect(viewModel.fetchedUntil == cachedUntil)   // 캐시 범위 복원 — loadInitial(+30일) 아님.

        await repo.releaseFetch()
        await appearTask.value
        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["fresh"])
    }

    /// fetchedUntil이 이미 지난 낡은 캐시는 버리고 기존 첫 페이지(loadInitial) 경로로 간다.
    @Test func staleSnapshotIsIgnored() async {
        let today = Calendar.current.startOfDay(for: Date())
        let pastEvent = event(id: "old",
                              start: today.addingTimeInterval(-48 * 60 * 60),
                              end: today.addingTimeInterval(-47 * 60 * 60))
        let cache = InMemorySnapshotCacheRepository(
            eventsSnapshot: EventsSnapshot(
                events: [pastEvent],
                fetchedUntil: today.addingTimeInterval(-24 * 60 * 60)
            )
        )
        let fresh = event(id: "fresh",
                          start: today.addingTimeInterval(10 * 60 * 60),
                          end: today.addingTimeInterval(11 * 60 * 60))
        var deps = makeDependencies(events: [fresh])
        deps.loadEventsSnapshot = LoadEventsSnapshotUseCase(repository: cache)
        deps.saveEventsSnapshot = SaveEventsSnapshotUseCase(repository: cache)
        let viewModel = ScheduleViewModel(dependencies: deps, now: { today })

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["fresh"])
        // loadInitial 경로 — fetch 범위가 오늘+30일로 새로 잡힌다.
        let expectedUntil = Calendar.current.date(byAdding: .day, value: 30, to: today)
        #expect(viewModel.fetchedUntil == expectedUntil)
    }

    /// 첫 페이지 적재가 성공하면 스냅샷을 저장한다 — 다음 실행의 첫 페인트 재료.
    @Test func loadInitialSavesSnapshot() async {
        let today = Calendar.current.startOfDay(for: Date())
        let item = event(id: "1",
                         start: today.addingTimeInterval(10 * 60 * 60),
                         end: today.addingTimeInterval(11 * 60 * 60))
        let cache = InMemorySnapshotCacheRepository()
        var deps = makeDependencies(events: [item])
        deps.loadEventsSnapshot = LoadEventsSnapshotUseCase(repository: cache)
        deps.saveEventsSnapshot = SaveEventsSnapshotUseCase(repository: cache)
        let viewModel = ScheduleViewModel(dependencies: deps, now: { today })

        await viewModel.onAppear()

        let saved = await cache.eventsSnapshot
        #expect(saved?.events.map(\.id) == ["1"])
        #expect(saved?.fetchedUntil == viewModel.fetchedUntil)
    }

    /// 프리페치 — 이미 권한이 허용된 경우에만 첫 페이지를 미리 적재한다.
    @Test func prefetchLoadsWhenAccessAlreadyGranted() async {
        let today = Calendar.current.startOfDay(for: Date())
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(
            events: [event(id: "1",
                           start: today.addingTimeInterval(10 * 60 * 60),
                           end: today.addingTimeInterval(11 * 60 * 60))]
        ), now: { today })

        await viewModel.prefetch()

        #expect(viewModel.access == .granted)
        #expect(viewModel.eventsByDay.flatMap(\.events).map(\.id) == ["1"])
    }

    /// 프리페치는 권한 프롬프트를 절대 유발하지 않는다 — 미결정이면 아무것도 하지 않는다.
    @Test func prefetchDoesNothingWhenAccessNotDetermined() async {
        let today = Calendar.current.startOfDay(for: Date())
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(
            access: .notDetermined,
            events: [event(id: "1",
                           start: today.addingTimeInterval(10 * 60 * 60),
                           end: today.addingTimeInterval(11 * 60 * 60))]
        ), now: { today })

        await viewModel.prefetch()

        #expect(viewModel.access == .notDetermined)
        #expect(viewModel.eventsByDay.isEmpty)
    }
}

// MARK: - 분석 이벤트 기록용 더블

/// `log(_:)`가 동기라 actor를 못 쓴다 — 테스트는 MainActor 단일 스레드라 @unchecked로 안전.
private final class SpyAnalyticsService: AnalyticsService, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func log(name: String, parameters: [String: String]) {}
}

/// `fetchEvents`를 게이트로 붙잡을 수 있는 리포지토리 더블 — 나머지는 InMemory에 위임한다.
/// `GatedRemindersRepository`(ReminderViewModelTests)와 같은 관측 패턴.
private actor GatedEventsRepository: EventsRepository {
    private let base: InMemoryEventsRepository
    private var gateClosed = false
    private(set) var isFetchWaiting = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(_ base: InMemoryEventsRepository) { self.base = base }

    func closeGate() { gateClosed = true }
    func releaseFetch() {
        gateClosed = false
        isFetchWaiting = false
        for waiter in waiters { waiter.resume() }
        waiters = []
    }

    func requestAccess() async -> EventsAccess { await base.requestAccess() }
    func currentAccess() async -> EventsAccess { await base.currentAccess() }
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent] {
        if gateClosed {
            isFetchWaiting = true
            await withCheckedContinuation { waiters.append($0) }
        }
        return try await base.fetchEvents(from: from, to: to)
    }
    func fetchCalendars() async throws -> [EventCalendar] { try await base.fetchCalendars() }
    nonisolated func changes() -> AsyncStream<Void> { base.changes() }
}
