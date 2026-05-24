//
//  ReminderViewModelTests.swift
//  cueTests
//

import Foundation
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
            addReminder: AddReminderUseCase(repository: remindersRepository),
            updateReminder: UpdateReminderUseCase(repository: remindersRepository),
            deleteReminder: DeleteReminderUseCase(repository: remindersRepository),
            addReminderList: AddReminderListUseCase(repository: remindersRepository),
            updateReminderList: UpdateReminderListUseCase(repository: remindersRepository),
            deleteReminderList: DeleteReminderListUseCase(repository: remindersRepository)
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

    @Test func addStoresNotes() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "장보기", notes: "우유 사기")

        #expect(viewModel.visibleReminders.first { $0.title == "장보기" }?.notes == "우유 사기")
    }

    @Test func updateStoresDueDate() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")]
        ))
        await viewModel.onAppear()
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.update(
            reminderID: "1", title: "마감 있는 일", notes: nil,
            dueDate: due, includesTime: true
        )

        let updated = viewModel.visibleReminders.first
        #expect(updated?.dueDate == due)
        #expect(updated?.includesTime == true)
    }

    @Test func updateChangesTitleAndNotes() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", title: "옛 제목", listID: "A")]
        ))
        await viewModel.onAppear()

        await viewModel.update(reminderID: "1", title: "새 제목", notes: "새 메모")

        #expect(viewModel.visibleReminders.first?.title == "새 제목")
        #expect(viewModel.visibleReminders.first?.notes == "새 메모")
    }

    @Test func addStoresDueDate() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.add(title: "마감", dueDate: due, includesTime: true)

        #expect(viewModel.visibleReminders.first { $0.title == "마감" }?.dueDate == due)
    }

    @Test func deleteRemovesReminder() async {
        let target = reminder(id: "1", listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()

        await viewModel.delete(target)

        #expect(viewModel.visibleReminders.isEmpty)
    }

    // MARK: - List CRUD

    @Test func addListCreatesAndSelectsNewList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.addList(title: "사이드 프로젝트", colorHex: "#FF9500")

        #expect(viewModel.lists.contains { $0.title == "사이드 프로젝트" })
        // 새로 만든 리스트로 자동 전환.
        #expect(viewModel.selectedList?.title == "사이드 프로젝트")
    }

    @Test func addListWithBlankTitleSurfacesError() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.addList(title: "   ", colorHex: nil)

        #expect(viewModel.errorMessage != nil)
        // selected는 그대로.
        #expect(viewModel.selectedListID == "A")
    }

    @Test func updateListChangesTitleAndColor() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.updateList(listID: "A", title: "새 이름", colorHex: "#34C759")

        let updated = viewModel.lists.first { $0.id == "A" }
        #expect(updated?.title == "새 이름")
        #expect(updated?.colorHex == "#34C759")
    }

    @Test func deleteListRemovesItAndMovesSelection() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [reminder(id: "1", listID: "A")]
        ))
        await viewModel.onAppear()
        // 첫 진입은 A 선택.

        await viewModel.deleteList(listID: "A")

        #expect(viewModel.lists.map(\.id) == ["B"])
        // 안 있던 항목도 함께 사라짐.
        #expect(viewModel.allReminders.isEmpty)
        // selected는 남은 첫 리스트로 옮겨감.
        #expect(viewModel.selectedListID == "B")
    }

    @Test func deleteListKeepsSelectionWhenOtherListDeleted() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB]
        ))
        await viewModel.onAppear()
        viewModel.select(listB)  // 현재 B 선택 중.

        await viewModel.deleteList(listID: "A")

        // 다른 리스트 삭제는 selection에 영향 없음.
        #expect(viewModel.selectedListID == "B")
    }
}
