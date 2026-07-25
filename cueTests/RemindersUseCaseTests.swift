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

    /// 반복은 마감일과 함께 저장된다 — 세부사항 시트의 반복 선택이 도메인까지 관통.
    @Test func addReminderStoresRecurrenceWithDueDate() async throws {
        let repository = makeRepository()
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [2, 4], endDate: Date(timeIntervalSince1970: 1_800_000_000))

        let created = try await AddReminderUseCase(repository: repository)(
            title: "반복 항목", dueDate: Date(), recurrence: rule, listID: "L1"
        )

        #expect(created.recurrence == rule)
    }

    /// 반복은 마감일 전제 — 날짜 없이 들어오면 무시한다(도메인 불변식).
    @Test func addReminderDropsRecurrenceWithoutDueDate() async throws {
        let repository = makeRepository()

        let created = try await AddReminderUseCase(repository: repository)(
            title: "항목", dueDate: nil, recurrence: RecurrenceRule(frequency: .daily), listID: "L1"
        )

        #expect(created.recurrence == nil)
    }

    /// update는 반복을 교체·제거할 수 있다 — nil이면 반복 해제.
    @Test func updateReminderReplacesAndClearsRecurrence() async throws {
        let repository = makeRepository(reminders: [makeReminder()])
        let id = try await FetchRemindersUseCase(repository: repository)().first!.id

        let updated = try await UpdateReminderUseCase(repository: repository)(
            reminderID: id, title: "제목", notes: nil,
            dueDate: Date(), recurrence: RecurrenceRule(frequency: .monthly, monthDays: [1, 15])
        )
        #expect(updated.recurrence == RecurrenceRule(frequency: .monthly, monthDays: [1, 15]))

        let cleared = try await UpdateReminderUseCase(repository: repository)(
            reminderID: id, title: "제목", notes: nil, dueDate: Date(), recurrence: nil
        )
        #expect(cleared.recurrence == nil)
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

    /// add는 저장된 항목을 돌려준다 — ViewModel이 재조회를 기다리지 않고 실제 id로
    /// 로컬 목록에 즉시(낙관적으로) 삽입하기 위한 계약. 저장 시 행 깜빡임 제거의 근간.
    @Test func addReminderReturnsCreatedReminder() async throws {
        let repository = makeRepository()

        let created = try await AddReminderUseCase(repository: repository)(
            title: "  새 항목  ", listID: "L1"
        )

        #expect(created.title == "새 항목")
        #expect(created.listID == "L1")
        let stored = try await FetchRemindersUseCase(repository: repository)()
        #expect(stored.contains { $0.id == created.id })
    }

    /// update도 갱신된 항목을 돌려준다 — 같은 id의 항목을 로컬에서 in-place 치환하기 위함.
    @Test func updateReminderReturnsUpdatedReminder() async throws {
        let repository = makeRepository(reminders: [makeReminder()])

        let updated = try await UpdateReminderUseCase(repository: repository)(
            reminderID: "R1", title: "  수정됨  ", notes: "메모"
        )

        #expect(updated.id == "R1")
        #expect(updated.title == "수정됨")
        #expect(updated.notes == "메모")
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

    // MARK: - List CRUD

    @Test func addReminderListReturnsNewID() async throws {
        let repository = makeRepository()

        let newID = try await AddReminderListUseCase(repository: repository)(
            title: "사이드 프로젝트", colorHex: "#FF9500"
        )

        let lists = try await FetchReminderListsUseCase(repository: repository)()
        #expect(lists.contains { $0.id == newID && $0.title == "사이드 프로젝트" })
    }

    @Test func addReminderListTrimsTitle() async throws {
        let repository = makeRepository()

        let newID = try await AddReminderListUseCase(repository: repository)(
            title: "  여백  ", colorHex: nil
        )

        let lists = try await FetchReminderListsUseCase(repository: repository)()
        #expect(lists.first { $0.id == newID }?.title == "여백")
    }

    @Test func addReminderListThrowsForBlankTitle() async {
        let repository = makeRepository()

        await #expect(throws: (any Error).self) {
            _ = try await AddReminderListUseCase(repository: repository)(
                title: "   ", colorHex: nil
            )
        }
    }

    @Test func updateReminderListChangesTitleAndColor() async throws {
        let repository = makeRepository()

        try await UpdateReminderListUseCase(repository: repository)(
            listID: "L1", title: "새 이름", colorHex: "#34C759"
        )

        let lists = try await FetchReminderListsUseCase(repository: repository)()
        let updated = lists.first { $0.id == "L1" }
        #expect(updated?.title == "새 이름")
        #expect(updated?.colorHex == "#34C759")
    }

    @Test func updateReminderListKeepsColorWhenHexIsNil() async throws {
        let repository = InMemoryRemindersRepository(
            access: .granted,
            lists: [ReminderList(id: "L1", title: "원본", colorHex: "#FF9500")]
        )

        try await UpdateReminderListUseCase(repository: repository)(
            listID: "L1", title: "이름만 변경", colorHex: nil
        )

        let lists = try await FetchReminderListsUseCase(repository: repository)()
        #expect(lists.first?.colorHex == "#FF9500")
    }

    @Test func updateReminderListThrowsForMissingID() async {
        let repository = makeRepository()

        await #expect(throws: (any Error).self) {
            try await UpdateReminderListUseCase(repository: repository)(
                listID: "없는ID", title: "x", colorHex: nil
            )
        }
    }

    @Test func deleteReminderListRemovesListAndItsReminders() async throws {
        let repository = makeRepository(reminders: [
            makeReminder(id: "R1"),
            makeReminder(id: "R2", title: "다른 리스트"),
        ])

        try await DeleteReminderListUseCase(repository: repository)(listID: "L1")

        let lists = try await FetchReminderListsUseCase(repository: repository)()
        let reminders = try await FetchRemindersUseCase(repository: repository)()
        #expect(lists.isEmpty)
        // L1에 속한 항목들도 함께 사라짐 — EventKit 동작과 동일.
        #expect(reminders.isEmpty)
    }

    @Test func deleteReminderListThrowsForMissingID() async {
        let repository = makeRepository()

        await #expect(throws: (any Error).self) {
            try await DeleteReminderListUseCase(repository: repository)(listID: "없는ID")
        }
    }

    // MARK: - 리스트 간 이동 (전체 탭 섹션 간 드래그)

    @Test func moveReminderChangesList() async throws {
        let repository = InMemoryRemindersRepository(
            access: .granted,
            lists: [list, ReminderList(id: "L2", title: "다른 리스트", colorHex: nil)],
            reminders: [makeReminder(id: "R1")]
        )

        try await MoveReminderUseCase(repository: repository)(reminderID: "R1", toListID: "L2")

        let moved = try await FetchRemindersUseCase(repository: repository)().first { $0.id == "R1" }
        #expect(moved?.listID == "L2")
    }

    @Test func moveReminderThrowsForMissingReminder() async {
        let repository = makeRepository()

        await #expect(throws: (any Error).self) {
            try await MoveReminderUseCase(repository: repository)(reminderID: "없는ID", toListID: "L1")
        }
    }

    @Test func moveReminderThrowsForMissingTargetList() async {
        let repository = makeRepository(reminders: [makeReminder(id: "R1")])

        await #expect(throws: (any Error).self) {
            try await MoveReminderUseCase(repository: repository)(reminderID: "R1", toListID: "없는ID")
        }
    }
}
