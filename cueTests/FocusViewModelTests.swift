//
//  FocusViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct FocusViewModelTests {

    /// 인메모리 fake로 의존성을 조립한다. 집중 탭은 노티 스케줄러만 쓰지만 `Dependencies`
    /// 묶음이 다른 필드들도 요구하므로 채워둔다.
    private func makeDependencies(
        scheduler: FakeFocusNotificationScheduler = FakeFocusNotificationScheduler()
    ) -> (Dependencies, FakeFocusNotificationScheduler) {
        let itemRepository = InMemoryItemRepository()
        let remindersRepository = InMemoryRemindersRepository(access: .granted)
        let eventsRepository = InMemoryEventsRepository(access: .granted)
        let deps = Dependencies(
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
            fetchEvents: FetchEventsUseCase(repository: eventsRepository),
            focusNotifications: scheduler
        )
        return (deps, scheduler)
    }

    @Test func initialStateHasDefaultSettingsAndNoSession() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        #expect(viewModel.settings == FocusSettings.default)
        #expect(viewModel.session == nil)
    }

    @Test func startCreatesSessionFromCurrentSettings() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.settings = FocusSettings(
            focusDuration: 90, restDuration: 30, isRepeating: false, cycleCount: 1
        )

        viewModel.start()

        #expect(viewModel.session?.phase == .focus)
        #expect(viewModel.session?.remaining == 90)
        #expect(viewModel.session?.totalCycles == 1)
    }

    @Test func stopSessionClearsAndAbortsCurrent() {
        let (deps, scheduler) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.start()

        viewModel.stopSession()

        #expect(viewModel.session == nil)
        // start 시 1번 schedule, abort 시 1번 cancel.
        #expect(scheduler.cancelCount >= 1)
    }

    @Test func cycleCountClampedToAtLeastOne() {
        // 사용자가 picker로 0을 선택해도 도메인은 1 이상으로 처리한다.
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.settings = FocusSettings(
            focusDuration: 60, restDuration: 30, isRepeating: true, cycleCount: 0
        )

        viewModel.start()

        #expect(viewModel.session?.totalCycles == 1)
    }
}
