//
//  ReminderViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 미리알림 탭의 상태 + 동작. UseCase에만 의존하며 SwiftUI를 import하지 않는다.
@MainActor
@Observable
final class ReminderViewModel {
    private let requestAccessUseCase: RequestRemindersAccessUseCase
    private let fetchListsUseCase: FetchReminderListsUseCase
    private let fetchRemindersUseCase: FetchRemindersUseCase
    private let toggleCompletionUseCase: ToggleReminderCompletionUseCase
    private let addReminderUseCase: AddReminderUseCase
    private let updateReminderUseCase: UpdateReminderUseCase
    private let deleteReminderUseCase: DeleteReminderUseCase

    private(set) var access: RemindersAccess = .notDetermined
    private(set) var lists: [ReminderList] = []
    private(set) var allReminders: [Reminder] = []
    private(set) var isLoading = false
    var selectedListID: String?
    var errorMessage: String?

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestRemindersAccess
        self.fetchListsUseCase = dependencies.fetchReminderLists
        self.fetchRemindersUseCase = dependencies.fetchReminders
        self.toggleCompletionUseCase = dependencies.toggleReminderCompletion
        self.addReminderUseCase = dependencies.addReminder
        self.updateReminderUseCase = dependencies.updateReminder
        self.deleteReminderUseCase = dependencies.deleteReminder
    }

    /// 현재 선택된 리스트.
    var selectedList: ReminderList? {
        lists.first { $0.id == selectedListID }
    }

    /// 선택된 리스트의 **미완료** 항목만. 완료된 항목은 숨긴다.
    var visibleReminders: [Reminder] {
        guard let selectedListID else { return [] }
        return allReminders.filter { $0.listID == selectedListID && !$0.isCompleted }
    }

    /// 화면 진입 시 — 권한을 확보하고 데이터를 적재한다.
    func onAppear() async {
        access = await requestAccessUseCase()
        guard access == .granted else { return }
        await reload()
    }

    /// 리스트·항목을 다시 가져온다. 선택된 리스트가 없거나 사라졌으면 첫 리스트를 고른다.
    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            if selectedList == nil {
                selectedListID = lists.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ list: ReminderList) {
        selectedListID = list.id
    }

    func toggle(_ reminder: Reminder) async {
        do {
            try await toggleCompletionUseCase(reminder)
            allReminders = try await fetchRemindersUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        includesTime: Bool = false
    ) async {
        guard let selectedListID else {
            errorMessage = "먼저 리스트를 선택해 주세요."
            return
        }
        do {
            try await addReminderUseCase(
                title: title,
                notes: notes,
                dueDate: dueDate,
                includesTime: includesTime,
                listID: selectedListID
            )
            allReminders = try await fetchRemindersUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 기존 항목의 제목·메모를 수정한다.
    func update(reminderID: String, title: String, notes: String?) async {
        do {
            try await updateReminderUseCase(reminderID: reminderID, title: title, notes: notes)
            allReminders = try await fetchRemindersUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 항목을 삭제한다.
    func delete(_ reminder: Reminder) async {
        do {
            try await deleteReminderUseCase(reminderID: reminder.id)
            allReminders = try await fetchRemindersUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
