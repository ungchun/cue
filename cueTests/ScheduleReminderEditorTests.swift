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
        reminders: [Reminder] = []
    ) -> (ScheduleReminderEditor, InMemoryRemindersRepository, SpyAnalyticsService) {
        let repository = InMemoryRemindersRepository(access: .granted, lists: [listA, listB], reminders: reminders)
        let analytics = SpyAnalyticsService()
        var dependencies = Dependencies.preview
        dependencies.fetchReminderLists = FetchReminderListsUseCase(repository: repository)
        dependencies.fetchReminders = FetchRemindersUseCase(repository: repository)
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
