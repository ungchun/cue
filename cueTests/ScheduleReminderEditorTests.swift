//
//  ScheduleReminderEditorTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ScheduleReminderEditorTests {

    private let listA = ReminderList(id: "list-a", title: "개인", colorHex: "#FF9500")
    private let listB = ReminderList(id: "list-b", title: "회사", colorHex: nil)
    private let due = Date(timeIntervalSince1970: 1_800_000_000)

    private func reminder(id: String, title: String = "장보기", isCompleted: Bool = false) -> Reminder {
        Reminder(id: id, title: title, isCompleted: isCompleted, notes: nil,
                 dueDate: due, includesTime: true, listID: listA.id)
    }

    /// 편집기가 쓰는 할일 UseCase만 인메모리로 바꿔 끼운다 — 나머지는 프리뷰 묶음 그대로(쓰이지 않음).
    private func makeEditor(
        access: RemindersAccess = .granted,
        lists: [ReminderList]? = nil,
        reminders: [Reminder] = []
    ) -> (ScheduleReminderEditor, InMemoryRemindersRepository, SpyAnalyticsService) {
        let repository = InMemoryRemindersRepository(access: access, lists: lists ?? [listA, listB], reminders: reminders)
        let analytics = SpyAnalyticsService()
        var dependencies = Dependencies.preview
        dependencies.requestRemindersAccess = RequestRemindersAccessUseCase(repository: repository)
        dependencies.fetchReminderLists = FetchReminderListsUseCase(repository: repository)
        dependencies.fetchReminders = FetchRemindersUseCase(repository: repository)
        dependencies.addReminder = AddReminderUseCase(repository: repository)
        dependencies.updateReminder = UpdateReminderUseCase(repository: repository)
        dependencies.toggleReminderCompletion = ToggleReminderCompletionUseCase(repository: repository)
        dependencies.deleteReminder = DeleteReminderUseCase(repository: repository)
        dependencies.analytics = analytics
        return (ScheduleReminderEditor(dependencies: dependencies), repository, analytics)
    }

    // MARK: - 열기

    @Test func presentLoadsListsAndOpensLookedUpReminder() async {
        let target = reminder(id: "r1")
        let (editor, _, _) = makeEditor(reminders: [target])

        await editor.present(reminderID: "r1", lookup: target)

        #expect(editor.editingReminder == target)
        #expect(editor.lists.map(\.id) == [listA.id, listB.id])
        #expect(editor.errorMessage == nil)
    }

    /// 월 VM에 원본이 없으면 저장소에서 다시 찾는다. 거기도 없으면(지워짐) 열지 않는다.
    @Test func presentWithoutLookupFallsBackToRepository() async {
        let target = reminder(id: "r1")
        let (editor, _, _) = makeEditor(reminders: [target])

        await editor.present(reminderID: "gone", lookup: nil)
        #expect(editor.editingReminder == nil)

        await editor.present(reminderID: "r1", lookup: nil)
        #expect(editor.editingReminder == target)
    }

    // MARK: - 저장

    @Test func saveForwardsChangesPersistsAndRefreshesOpenSheet() async throws {
        let target = reminder(id: "r1")
        let (editor, repository, analytics) = makeEditor(reminders: [target])
        await editor.present(reminderID: "r1", lookup: target)
        var changes = ReminderChanges(from: target)
        changes.title = "우유 사기"
        changes.priority = .high
        changes.listID = listB.id

        await editor.save(reminderID: "r1", changes: changes)

        let all = try await repository.fetchReminders()
        let stored = try #require(all.first)
        #expect(stored.title == "우유 사기")
        #expect(stored.priority == .high)
        #expect(stored.listID == listB.id)
        #expect(editor.editingReminder == stored)
        #expect(analytics.events == [.reminderUpdated])
    }

    /// 사용자가 시트를 먼저 닫았으면 저장이 끝나도 시트를 다시 열지 않는다.
    @Test func saveAfterDismissDoesNotReopenSheet() async {
        let target = reminder(id: "r1")
        let (editor, _, _) = makeEditor(reminders: [target])
        await editor.present(reminderID: "r1", lookup: target)
        editor.dismiss()

        await editor.save(reminderID: "r1", changes: ReminderChanges(from: target))

        #expect(editor.editingReminder == nil)
    }

    @Test func saveFailureSetsErrorMessage() async {
        let target = reminder(id: "r1")
        let (editor, _, analytics) = makeEditor(reminders: [target])
        await editor.present(reminderID: "r1", lookup: target)
        var changes = ReminderChanges(from: target)
        changes.title = "  "

        await editor.save(reminderID: "r1", changes: changes)

        #expect(editor.errorMessage == DomainError.validation(String(localized: "Please enter a title.")).localizedDescription)
        #expect(editor.editingReminder == target)
        #expect(analytics.events.isEmpty)
    }

    // MARK: - 완료 토글

    @Test func toggleCompletionFlipsBothWaysAndLogsDirection() async throws {
        let target = reminder(id: "r1")
        let (editor, repository, analytics) = makeEditor(reminders: [target])
        await editor.present(reminderID: "r1", lookup: target)

        await editor.toggleCompletion(reminderID: "r1")
        let completed = try await repository.fetchReminders()
        #expect(completed.first?.isCompleted == true)
        #expect(editor.editingReminder?.isCompleted == true)

        await editor.toggleCompletion(reminderID: "r1")
        let reopened = try await repository.fetchReminders()
        #expect(reopened.first?.isCompleted == false)
        #expect(editor.editingReminder?.isCompleted == false)
        #expect(analytics.events == [.reminderCompleted(source: "app"), .reminderUncompleted])
    }

    /// 저장·재조회가 끝나기 전 다시 탭해도 한 번만 완료한다 — 옛 값으로 두 번 완료하면
    /// 반복 할일이 두 회차 넘어간다.
    @Test func toggleCompletionIgnoresTapWhileSaving() async throws {
        let target = reminder(id: "r1")
        let (editor, repository, analytics) = makeEditor(reminders: [target])
        await editor.present(reminderID: "r1", lookup: target)

        async let first: Void = editor.toggleCompletion(reminderID: "r1")
        async let second: Void = editor.toggleCompletion(reminderID: "r1")
        _ = await (first, second)

        let stored = try await repository.fetchReminders()
        #expect(stored.first?.isCompleted == true)
        #expect(analytics.events == [.reminderCompleted(source: "app")])

        await editor.toggleCompletion(reminderID: "r1")
        #expect(editor.editingReminder?.isCompleted == false)
    }

    /// 저장소에 없는 할일(그새 외부에서 지워짐)을 완료하면 실패를 알리고 시트 값은 그대로 둔다.
    @Test func toggleFailureSetsErrorMessageAndKeepsState() async {
        let stale = reminder(id: "stale")
        let (editor, _, analytics) = makeEditor()
        await editor.present(reminderID: "stale", lookup: stale)

        await editor.toggleCompletion(reminderID: "stale")

        #expect(editor.errorMessage == DomainError.notFound.localizedDescription)
        #expect(editor.editingReminder?.isCompleted == false)
        #expect(analytics.events.isEmpty)
    }

    // MARK: - 삭제

    @Test func deleteRemovesReminderAndClosesSheet() async throws {
        let target = reminder(id: "r1")
        let (editor, repository, analytics) = makeEditor(reminders: [target, reminder(id: "r2")])
        await editor.present(reminderID: "r1", lookup: target)

        await editor.delete(reminderID: "r1")

        let remaining = try await repository.fetchReminders()
        #expect(remaining.map(\.id) == ["r2"])
        #expect(editor.editingReminder == nil)
        #expect(analytics.events == [.reminderDeleted])
    }

    @Test func deleteFailureSetsErrorMessageAndKeepsSheetOpen() async {
        let stale = reminder(id: "stale")
        let (editor, _, _) = makeEditor()
        await editor.present(reminderID: "stale", lookup: stale)

        await editor.delete(reminderID: "stale")

        #expect(editor.errorMessage == DomainError.notFound.localizedDescription)
        #expect(editor.editingReminder == stale)
    }

    // MARK: - 생성 (+ 시트)

    /// 기본 목록은 isDefault 목록 — 이름·순서와 무관(로케일마다 이름이 다르다).
    @Test func refreshListsLoadsListsAndPicksDefaultList() async {
        let defaultList = ReminderList(id: "list-def", title: "Reminders", colorHex: nil, isDefault: true)
        let (editor, _, _) = makeEditor(lists: [listA, defaultList])

        await editor.refreshLists()

        #expect(editor.lists.map(\.id) == [listA.id, defaultList.id])
        #expect(editor.defaultListID == defaultList.id)
    }

    /// 할일 탭을 안 연 사용자도 + 시트의 할일 쪽에서 권한을 묻고 목록을 받는다.
    @Test func prepareForCreateRequestsAccessThenLoadsLists() async {
        let (editor, repository, _) = makeEditor(access: .notDetermined)

        await editor.prepareForCreate()

        #expect(await repository.currentAccess() == .granted)
        #expect(editor.defaultListID == listA.id)
    }

    @Test func defaultListFallsBackToFirstListThenNil() async {
        let (editor, _, _) = makeEditor()
        #expect(editor.defaultListID == nil)

        await editor.refreshLists()

        #expect(editor.defaultListID == listA.id)
    }

    @Test func createStoresIntoChosenListAndLogs() async throws {
        let (editor, repository, analytics) = makeEditor()
        await editor.refreshLists()

        await editor.create(
            title: "우유 사기", notes: "2통",
            dueDate: due, includesTime: false, recurrence: nil,
            listID: listB.id
        )

        let stored = try await repository.fetchReminders()
        #expect(stored.count == 1)
        #expect(stored.first?.title == "우유 사기")
        #expect(stored.first?.notes == "2통")
        #expect(stored.first?.dueDate == due)
        #expect(stored.first?.includesTime == false)
        #expect(stored.first?.listID == listB.id)
        #expect(analytics.events == [.reminderCreated])
        #expect(editor.errorMessage == nil)
    }

    /// 목록을 안 골랐으면(nil) 기본 목록으로.
    @Test func createWithoutListUsesDefaultList() async throws {
        let (editor, repository, _) = makeEditor()
        await editor.refreshLists()

        await editor.create(
            title: "우유 사기", notes: nil,
            dueDate: nil, includesTime: false, recurrence: nil,
            listID: nil
        )

        #expect(try await repository.fetchReminders().map(\.listID) == [listA.id])
    }

    /// 목록이 하나도 없으면 저장하지 않고 알린다.
    @Test func createWithoutAnyListSetsErrorMessage() async throws {
        let (editor, repository, analytics) = makeEditor(lists: [])
        await editor.refreshLists()

        await editor.create(
            title: "우유 사기", notes: nil,
            dueDate: nil, includesTime: false, recurrence: nil,
            listID: nil
        )

        #expect(editor.errorMessage == String(localized: "Select a list first."))
        #expect(try await repository.fetchReminders().isEmpty)
        #expect(analytics.events.isEmpty)
    }

    @Test func createFailureSetsErrorMessage() async throws {
        let (editor, repository, analytics) = makeEditor()
        await editor.refreshLists()

        await editor.create(
            title: "  ", notes: nil,
            dueDate: nil, includesTime: false, recurrence: nil,
            listID: listA.id
        )

        #expect(editor.errorMessage == DomainError.validation(String(localized: "Please enter a title.")).localizedDescription)
        #expect(try await repository.fetchReminders().isEmpty)
        #expect(analytics.events.isEmpty)
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
