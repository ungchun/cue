//
//  RemindersUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct RemindersUseCaseTests {

    private let list = ReminderList(id: "L1", title: "테스트", colorHex: nil)

    private func makeRepository(reminders: [Reminder] = []) -> InMemoryRemindersRepository {
        InMemoryRemindersRepository(access: .granted, lists: [list], reminders: reminders)
    }

    private func makeReminder(
        id: String = "R1",
        title: String = "할 일",
        isCompleted: Bool = false
    ) -> Reminder {
        Reminder(
            id: id, title: title, isCompleted: isCompleted,
            notes: nil, dueDate: nil, listID: "L1"
        )
    }

    @Test func requestAccessGrantsWhenNotDetermined() async {
        let repository = InMemoryRemindersRepository(access: .notDetermined)

        let result = await RequestRemindersAccessUseCase(repository: repository)()

        #expect(result == .granted)
    }

    @Test func requestAccessKeepsDeniedState() async {
        let repository = InMemoryRemindersRepository(access: .denied)

        let result = await RequestRemindersAccessUseCase(repository: repository)()

        #expect(result == .denied)
    }

    @Test func fetchReminderListsReturnsLists() async throws {
        let lists = try await FetchReminderListsUseCase(repository: makeRepository())()

        #expect(lists == [list])
    }

    @Test func fetchRemindersReturnsAllReminders() async throws {
        let reminder = makeReminder()
        let repository = makeRepository(reminders: [reminder])

        let reminders = try await FetchRemindersUseCase(repository: repository)()

        #expect(reminders == [reminder])
    }

    @Test func toggleCompletionFlipsIncompleteToCompleted() async throws {
        let reminder = makeReminder(isCompleted: false)
        let repository = makeRepository(reminders: [reminder])

        try await ToggleReminderCompletionUseCase(repository: repository)(reminder)

        let updated = try await FetchRemindersUseCase(repository: repository)()
        #expect(updated.first?.isCompleted == true)
    }

    @Test func toggleCompletionFlipsCompletedToIncomplete() async throws {
        let reminder = makeReminder(isCompleted: true)
        let repository = makeRepository(reminders: [reminder])

        try await ToggleReminderCompletionUseCase(repository: repository)(reminder)

        let updated = try await FetchRemindersUseCase(repository: repository)()
        #expect(updated.first?.isCompleted == false)
    }

    @Test func addReminderInsertsIntoList() async throws {
        let repository = makeRepository()

        try await AddReminderUseCase(repository: repository)(title: "새 항목", listID: "L1")

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.contains { $0.title == "새 항목" && $0.listID == "L1" })
    }

    @Test func addReminderTrimsWhitespace() async throws {
        let repository = makeRepository()

        try await AddReminderUseCase(repository: repository)(title: "  공백  ", listID: "L1")

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.title == "공백")
    }

    @Test func addReminderWithBlankTitleThrows() async {
        let repository = makeRepository()

        await #expect(throws: DomainError.self) {
            try await AddReminderUseCase(repository: repository)(title: "   ", listID: "L1")
        }
    }

    @Test func addReminderStoresNotes() async throws {
        let repository = makeRepository()

        try await AddReminderUseCase(repository: repository)(
            title: "장보기", notes: "우유 사기", listID: "L1"
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.notes == "우유 사기")
    }

    @Test func addReminderWithBlankNotesStoresNil() async throws {
        let repository = makeRepository()

        try await AddReminderUseCase(repository: repository)(
            title: "장보기", notes: "   ", listID: "L1"
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.notes == nil)
    }

    @Test func updateReminderChangesTitleAndNotes() async throws {
        let repository = makeRepository(reminders: [makeReminder(id: "R1", title: "옛 제목")])

        try await UpdateReminderUseCase(repository: repository)(
            reminderID: "R1", title: "새 제목", notes: "새 메모"
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.title == "새 제목")
        #expect(reminders.first?.notes == "새 메모")
    }

    @Test func updateReminderTrimsTitle() async throws {
        let repository = makeRepository(reminders: [makeReminder(id: "R1")])

        try await UpdateReminderUseCase(repository: repository)(
            reminderID: "R1", title: "  공백  ", notes: nil
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.title == "공백")
    }

    @Test func updateReminderWithBlankTitleThrows() async {
        let repository = makeRepository(reminders: [makeReminder(id: "R1")])

        await #expect(throws: DomainError.self) {
            try await UpdateReminderUseCase(repository: repository)(
                reminderID: "R1", title: " ", notes: nil
            )
        }
    }

    @Test func updateReminderWithMissingIDThrows() async {
        let repository = makeRepository()

        await #expect(throws: DomainError.self) {
            try await UpdateReminderUseCase(repository: repository)(
                reminderID: "없는ID", title: "제목", notes: nil
            )
        }
    }

    @Test func deleteReminderRemovesItem() async throws {
        let repository = makeRepository(reminders: [makeReminder(id: "R1")])

        try await DeleteReminderUseCase(repository: repository)(reminderID: "R1")

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.isEmpty)
    }

    @Test func deleteReminderWithMissingIDThrows() async {
        let repository = makeRepository()

        await #expect(throws: DomainError.self) {
            try await DeleteReminderUseCase(repository: repository)(reminderID: "없는ID")
        }
    }

    @Test func updateReminderChangesDueDate() async throws {
        let repository = makeRepository(reminders: [makeReminder(id: "R1")])
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        try await UpdateReminderUseCase(repository: repository)(
            reminderID: "R1", title: "할 일", notes: nil,
            dueDate: due, includesTime: true
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.dueDate == due)
        #expect(reminders.first?.includesTime == true)
    }

    @Test func addReminderStoresDueDate() async throws {
        let repository = makeRepository()
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        try await AddReminderUseCase(repository: repository)(
            title: "마감 있는 일", dueDate: due, includesTime: true, listID: "L1"
        )

        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(reminders.first?.dueDate == due)
    }
}
