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

    // MARK: - 초기 상태 / 시작·정지

    @Test func initialStateHasNoSessionsAndNoSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.selectedSessionID == nil)
        #expect(viewModel.selectedSession == nil)
        #expect(viewModel.displayedSettings == FocusSettings.default)
        #expect(viewModel.session == nil)
    }

    @Test func startUsesSelectedSessionSettings() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 90, restDuration: 30, isRepeating: false, cycleCount: 1)
        let added = viewModel.addSession(title: "테스트", settings: custom, colorHex: "#34C759")
        viewModel.selectSession(id: added.id)

        viewModel.start()

        #expect(viewModel.session?.phase == .focus)
        #expect(viewModel.session?.remaining == 90)
        #expect(viewModel.session?.totalCycles == 1)
    }

    @Test func startWithoutSelectionUsesDefaultSettings() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        viewModel.start()

        #expect(viewModel.session?.remaining == FocusSettings.default.focusDuration)
    }

    @Test func startIsNoopWhenAlreadyRunning() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.start()
        let first = viewModel.session

        viewModel.start()

        // 같은 인스턴스가 그대로 — 두 번째 start로 새 세션이 만들어지지 않는다.
        #expect(viewModel.session === first)
    }

    @Test func stopSessionClearsAndAbortsCurrent() {
        let (deps, scheduler) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.start()

        viewModel.stopSession()

        #expect(viewModel.session == nil)
        #expect(scheduler.cancelCount >= 1)
    }

    // MARK: - 세션 CRUD

    @Test func addSessionAppendsToList() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 30 * 60, restDuration: 5 * 60, isRepeating: true, cycleCount: 4)

        let added = viewModel.addSession(title: "독서", settings: custom, colorHex: "#FF9500")

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == added.id)
        #expect(viewModel.sessions[0].title == "독서")
        #expect(viewModel.sessions[0].settings == custom)
        #expect(viewModel.sessions[0].colorHex == "#FF9500")
    }

    @Test func updateSessionReplacesInPlace() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let original = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")
        let newSettings = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)

        viewModel.updateSession(id: original.id, title: "운동", settings: newSettings, colorHex: "#34C759")

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == original.id)
        #expect(viewModel.sessions[0].title == "운동")
        #expect(viewModel.sessions[0].settings == newSettings)
        #expect(viewModel.sessions[0].colorHex == "#34C759")
    }

    @Test func updateSessionWithUnknownIDIsNoop() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.addSession(title: "원본", settings: .default, colorHex: "#FF3B30")

        viewModel.updateSession(id: UUID(), title: "다른", settings: .default, colorHex: "#FF3B30")

        #expect(viewModel.sessions[0].title == "원본")
    }

    @Test func deleteSessionRemovesFromList() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let a = viewModel.addSession(title: "A", settings: .default, colorHex: "#FF3B30")
        let b = viewModel.addSession(title: "B", settings: .default, colorHex: "#FF9500")

        viewModel.deleteSession(id: a.id)

        #expect(viewModel.sessions.map(\.id) == [b.id])
    }

    @Test func deletingSelectedSessionClearsSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let added = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")
        viewModel.selectSession(id: added.id)

        viewModel.deleteSession(id: added.id)

        #expect(viewModel.selectedSessionID == nil)
    }

    @Test func deletingNonSelectedSessionKeepsSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let kept = viewModel.addSession(title: "유지", settings: .default, colorHex: "#FF3B30")
        let toRemove = viewModel.addSession(title: "삭제", settings: .default, colorHex: "#FF9500")
        viewModel.selectSession(id: kept.id)

        viewModel.deleteSession(id: toRemove.id)

        #expect(viewModel.selectedSessionID == kept.id)
    }

    // MARK: - 선택

    @Test func selectSessionUpdatesDisplayedSettings() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)
        let added = viewModel.addSession(title: "글쓰기", settings: custom, colorHex: "#5856D6")

        viewModel.selectSession(id: added.id)

        #expect(viewModel.selectedSession?.id == added.id)
        #expect(viewModel.displayedSettings == custom)
    }

    @Test func selectingUnknownIDKeepsDisplayedSettingsAtDefault() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        viewModel.selectSession(id: UUID())

        #expect(viewModel.selectedSession == nil)
        #expect(viewModel.displayedSettings == FocusSettings.default)
    }
}
