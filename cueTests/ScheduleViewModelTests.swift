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
        let itemRepository = InMemoryItemRepository()
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
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository)
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
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [event1]))

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
        ]))

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
        let viewModel = ScheduleViewModel(dependencies: makeDependencies(events: [later, earlier]))

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
        ]))

        await viewModel.onAppear()

        #expect(viewModel.eventsByDay.map(\.date) == [today, dayAfter])
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
