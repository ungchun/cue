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
        events: [CalendarEvent] = []
    ) -> Dependencies {
        let eventsRepository = InMemoryEventsRepository(access: access, events: events)
        let remindersRepository = InMemoryRemindersRepository(access: .granted)
        let reminderSortRepository = InMemoryReminderSortRepository()
        let itemRepository = InMemoryItemRepository()
        let focusSessionsRepository = InMemoryFocusSessionsRepository()
        return Dependencies(
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
            fetchAppSettings: FetchAppSettingsUseCase(repository: InMemoryAppSettingsRepository()),
            saveAppSettings: SaveAppSettingsUseCase(repository: InMemoryAppSettingsRepository())
        )
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
        isReadOnly: Bool = false
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title,
            startDate: start, endDate: end,
            isAllDay: isAllDay, calendarColorHex: nil,
            isReadOnly: isReadOnly
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
}
