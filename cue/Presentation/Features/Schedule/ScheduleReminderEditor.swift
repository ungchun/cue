//
//  ScheduleReminderEditor.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭(월 캘린더)에서 할일 칩을 탭해 여는 상세 시트의 상태 + 동작 — 완료 토글·수정·삭제,
/// 그리고 + 시트의 할일 쪽 생성.
///
/// 할일 탭의 `ReminderViewModel`에 기대지 않는다 — 그쪽은 목록·선택·낙관적 반영까지 들고 있는
/// 할일 탭 전용이다. 여기선 UseCase만 부르고, 월 칩 갱신은 월 VM의 EventKit 변경 구독이 맡는다.
@MainActor
@Observable
final class ScheduleReminderEditor {
    private let requestRemindersAccess: RequestRemindersAccessUseCase
    private let fetchReminderLists: FetchReminderListsUseCase
    private let fetchReminders: FetchRemindersUseCase
    private let addReminder: AddReminderUseCase
    private let updateReminder: UpdateReminderUseCase
    private let toggleReminderCompletion: ToggleReminderCompletionUseCase
    private let deleteReminder: DeleteReminderUseCase
    private let analytics: any AnalyticsService

    /// 상세 시트에 띄운 할일. nil이면 닫힘 — `.sheet(item:)`이 바인딩한다.
    var editingReminder: Reminder?
    /// 시트의 리스트 선택지 — 열 때마다 새로 읽어 할일 탭에서 만든 리스트도 보이게.
    private(set) var lists: [ReminderList] = []
    /// 저장·완료·삭제 실패 메시지 — View가 alert로 표시.
    var errorMessage: String?
    /// 완료 저장·재조회 중인 할일 — 그새 다시 탭하면 옛 값으로 한 번 더 완료해 반복 회차를 건너뛴다.
    private var pendingCompletionIDs: Set<String> = []

    init(dependencies: Dependencies) {
        self.requestRemindersAccess = dependencies.requestRemindersAccess
        self.fetchReminderLists = dependencies.fetchReminderLists
        self.fetchReminders = dependencies.fetchReminders
        self.addReminder = dependencies.addReminder
        self.updateReminder = dependencies.updateReminder
        self.toggleReminderCompletion = dependencies.toggleReminderCompletion
        self.deleteReminder = dependencies.deleteReminder
        self.analytics = dependencies.analytics
    }

    /// 칩 탭 — 리스트를 읽은 뒤 시트를 연다(리스트 없이 열면 목록 행이 빈 채로 그려진다).
    /// `lookup`은 월 VM이 받아 둔 원본. 없으면(그새 외부에서 바뀜) 저장소에서 다시 찾고,
    /// 그래도 없으면 지워진 할일이라 열지 않는다.
    func present(reminderID: String, lookup: Reminder?) async {
        do {
            lists = try await fetchReminderLists()
            let reminder: Reminder?
            if let lookup {
                reminder = lookup
            } else {
                reminder = try await fetchReminders().first { $0.id == reminderID }
            }
            guard let reminder else { return }
            editingReminder = reminder
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 시트 저장 — 시트가 아직 이 할일을 보고 있으면 저장된 값으로 바꿔 보기 모드에 반영한다.
    func save(reminderID: String, changes: ReminderChanges) async {
        do {
            let updated = try await updateReminder(reminderID: reminderID, changes: changes)
            analytics.log(.reminderUpdated)
            replaceIfPresented(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 시트의 완료 토글 — 할일 탭과 같은 방향별 기록.
    func toggleCompletion(reminderID: String) async {
        guard let current = editingReminder, current.id == reminderID,
              pendingCompletionIDs.insert(reminderID).inserted else { return }
        defer { pendingCompletionIDs.remove(reminderID) }
        do {
            try await toggleReminderCompletion(current)
            if !current.isCompleted {
                analytics.log(.reminderCompleted(source: "app"))
            } else {
                analytics.log(.reminderUncompleted)
            }
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        var toggled = current
        toggled.isCompleted.toggle()
        // 반복 할일은 완료하면 EventKit이 다음 회차로 넘겨 미완료로 남는다 — 저장소 값으로 다시 맞춘다.
        // 재조회 실패는 쓰기 실패가 아니라 알리지 않고 뒤집은 값으로 둔다(월 칩은 변경 구독이 맞춘다).
        do {
            let stored = try await fetchReminders().first { $0.id == reminderID }
            replaceIfPresented(stored ?? toggled)
        } catch {
            replaceIfPresented(toggled)
        }
    }

    /// 시트의 삭제 — 성공하면 시트를 닫는다.
    func delete(reminderID: String) async {
        do {
            try await deleteReminder(reminderID: reminderID)
            analytics.log(.reminderDeleted)
            if editingReminder?.id == reminderID { editingReminder = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - 생성 (+ 시트)

    /// + 시트를 열기 전에 목록 선택지를 새로 읽는다. 실패(권한 없음 등)는 알리지 않고 빈 목록 —
    /// 할일 쪽으로 바꿔 저장할 때 `create`가 알린다.
    func refreshLists() async {
        lists = (try? await fetchReminderLists()) ?? []
    }

    /// + 시트가 할일 쪽으로 바뀔 때 — 할일 탭을 한 번도 안 연 사용자는 권한이 미결정이라
    /// 목록이 비고 저장이 조용히 실패한다. 여기서 묻고 목록을 다시 읽는다.
    func prepareForCreate() async {
        _ = await requestRemindersAccess()
        await refreshLists()
    }

    /// 새 할일의 기본 목록 — 미리 알림의 기본 목록, 없으면 첫 목록.
    var defaultListID: String? {
        lists.first(where: \.isDefault)?.id ?? lists.first?.id
    }

    /// + 시트의 할일 저장. 목록을 안 골랐으면 기본 목록으로. 월 칩은 변경 구독이 갱신한다.
    func create(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        recurrence: RecurrenceRule?,
        listID: String?
    ) async {
        guard let listID = listID ?? defaultListID else {
            errorMessage = String(localized: "Select a list first.")
            return
        }
        do {
            try await addReminder(
                title: title, notes: notes,
                dueDate: dueDate, includesTime: includesTime, recurrence: recurrence,
                listID: listID
            )
            analytics.log(.reminderCreated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismiss() {
        editingReminder = nil
    }

    /// 쓰기가 끝났을 때 시트가 그 할일을 아직 띄우고 있을 때만 갈아 끼운다 — 사용자가 먼저
    /// 닫았는데 다시 채우면 닫힌 시트가 도로 열린다.
    private func replaceIfPresented(_ reminder: Reminder) {
        guard editingReminder?.id == reminder.id else { return }
        editingReminder = reminder
    }
}
