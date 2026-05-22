//
//  ReminderViewModelTests.swift
//  cueTests
//

import Testing
@testable import cue

@MainActor
struct ReminderViewModelTests {

    private let listA = ReminderList(id: "A", title: "회사", colorHex: nil)
    private let listB = ReminderList(id: "B", title: "개인", colorHex: nil)

    /// 인메모리 fake로 의존성을 조립한다 (EventKit·SwiftData 없이 동작).
    private func makeDependencies(
        access: RemindersAccess = .granted,
        lists: [ReminderList] = [],
        reminders: [Reminder] = []
    ) -> Dependencies {
        let remindersRepository = InMemoryRemindersRepository(
            access: access, lists: lists, reminders: reminders
        )
        let itemRepository = InMemoryItemRepository()
        return Dependencies(
            fetchItems: FetchItemsUseCase(repository: itemRepository),
            addItem: AddItemUseCase(repository: itemRepository),
            deleteItem: DeleteItemUseCase(repository: itemRepository),
            requestRemindersAccess: RequestRemindersAccessUseCase(repository: remindersRepository),
            fetchReminderLists: FetchReminderListsUseCase(repository: remindersRepository),
            fetchReminders: FetchRemindersUseCase(repository: remindersRepository),
            toggleReminderCompletion: ToggleReminderCompletionUseCase(repository: remindersRepository),
            addReminder: AddReminderUseCase(repository: remindersRepository)
        )
    }

    private func reminder(
        id: String, title: String = "할 일",
        isCompleted: Bool = false, listID: String
    ) -> Reminder {
        Reminder(
            id: id, title: title, isCompleted: isCompleted,
            notes: nil, dueDate: nil, listID: listID
        )
    }

    @Test func onAppearGrantsAccessAndLoadsData() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .notDetermined,
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")]
        ))

        await viewModel.onAppear()

        #expect(viewModel.access == .granted)
        #expect(viewModel.lists == [listA])
        #expect(viewModel.allReminders.count == 1)
    }

    @Test func onAppearWithDeniedAccessLoadsNothing() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .denied, lists: [listA]
        ))

        await viewModel.onAppear()

        #expect(viewModel.access == .denied)
        #expect(viewModel.lists.isEmpty)
    }

    @Test func reloadSelectsFirstListByDefault() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA, listB]))

        await viewModel.onAppear()

        #expect(viewModel.selectedListID == "A")
    }

    @Test func visibleRemindersShowsOnlySelectedList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", listID: "A"),
                reminder(id: "2", listID: "B"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.select(listB)

        #expect(viewModel.visibleReminders.map(\.id) == ["2"])
    }

    @Test func visibleRemindersHidesCompleted() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", isCompleted: false, listID: "A"),
                reminder(id: "2", isCompleted: true, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        #expect(viewModel.visibleReminders.map(\.id) == ["1"])
    }

    @Test func toggleFlipsCompletion() async {
        let target = reminder(id: "1", isCompleted: false, listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()

        await viewModel.toggle(target)

        #expect(viewModel.allReminders.first?.isCompleted == true)
    }

    @Test func addInsertsReminderIntoSelectedList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "새 미리알림")

        #expect(viewModel.visibleReminders.contains { $0.title == "새 미리알림" })
    }

    @Test func addWithBlankTitleSurfacesError() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "   ")

        #expect(viewModel.errorMessage != nil)
    }
}
