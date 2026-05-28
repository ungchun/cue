//
//  ScheduleViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ScheduleViewModelTests {

    /// 인메모리 fake로 일정 탭 의존성을 조립한다 — Schedule은 권한만 알면 된다.
    /// 미리알림·아이템 UseCase는 일정 탭에 쓰이지 않지만 `Dependencies` 묶음이 요구하므로
    /// 채워둔다.
    private func makeDependencies(access: EventsAccess = .granted) -> Dependencies {
        let eventsRepository = InMemoryEventsRepository(access: access)
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
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository)
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
}
