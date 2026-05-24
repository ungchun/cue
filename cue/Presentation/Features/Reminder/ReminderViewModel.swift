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
    private let addReminderListUseCase: AddReminderListUseCase
    private let updateReminderListUseCase: UpdateReminderListUseCase
    private let deleteReminderListUseCase: DeleteReminderListUseCase

    private(set) var access: RemindersAccess = .notDetermined
    private(set) var lists: [ReminderList] = []
    private(set) var allReminders: [Reminder] = []
    private(set) var isLoading = false
    var selectedListID: String?
    var errorMessage: String?
    /// 옵션 메뉴 — 완료된 항목 섹션을 함께 보여줄지. 기본 OFF.
    var showsCompleted = false

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestRemindersAccess
        self.fetchListsUseCase = dependencies.fetchReminderLists
        self.fetchRemindersUseCase = dependencies.fetchReminders
        self.toggleCompletionUseCase = dependencies.toggleReminderCompletion
        self.addReminderUseCase = dependencies.addReminder
        self.updateReminderUseCase = dependencies.updateReminder
        self.deleteReminderUseCase = dependencies.deleteReminder
        self.addReminderListUseCase = dependencies.addReminderList
        self.updateReminderListUseCase = dependencies.updateReminderList
        self.deleteReminderListUseCase = dependencies.deleteReminderList
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

    /// 리스트별 미완료 항목 수 — 리스트 선택 메뉴 옆 카운트 표기용.
    func incompleteCount(for list: ReminderList) -> Int {
        allReminders.reduce(into: 0) { count, reminder in
            if reminder.listID == list.id && !reminder.isCompleted { count += 1 }
        }
    }

    /// 선택된 리스트의 **완료** 항목 — "완료된 항목 보기" 토글이 켜졌을 때만 화면에 추가된다.
    var completedReminders: [Reminder] {
        guard let selectedListID else { return [] }
        return allReminders.filter { $0.listID == selectedListID && $0.isCompleted }
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

    /// 기존 항목의 제목·메모·마감일을 수정한다.
    func update(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date? = nil,
        includesTime: Bool = false
    ) async {
        do {
            try await updateReminderUseCase(
                reminderID: reminderID,
                title: title,
                notes: notes,
                dueDate: dueDate,
                includesTime: includesTime
            )
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

    /// 새 리스트 생성 — 만들고 나서 그 리스트로 자동 전환한다.
    func addList(title: String, colorHex: String?) async {
        do {
            let newID = try await addReminderListUseCase(title: title, colorHex: colorHex)
            lists = try await fetchListsUseCase()
            selectedListID = newID
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 기존 리스트의 이름·색을 수정.
    func updateList(listID: String, title: String, colorHex: String?) async {
        do {
            try await updateReminderListUseCase(listID: listID, title: title, colorHex: colorHex)
            lists = try await fetchListsUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 리스트 삭제 — 안에 있는 모든 항목도 함께 사라진다.
    /// 삭제 후 selectedListID는 남은 첫 리스트로(없으면 nil) 옮긴다.
    func deleteList(listID: String) async {
        do {
            try await deleteReminderListUseCase(listID: listID)
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            if selectedListID == listID {
                selectedListID = lists.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
