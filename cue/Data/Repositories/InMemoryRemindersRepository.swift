//
//  InMemoryRemindersRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. EventKit·권한 없이 동작한다.
///
/// `actor`로 격리해 `Sendable`을 만족하며, 어느 컨텍스트에서든 생성할 수 있다.
actor InMemoryRemindersRepository: RemindersRepository {
    private var access: RemindersAccess
    private var lists: [ReminderList]
    private var reminders: [Reminder]

    init(
        access: RemindersAccess = .granted,
        lists: [ReminderList] = [],
        reminders: [Reminder] = []
    ) {
        self.access = access
        self.lists = lists
        self.reminders = reminders
    }

    func requestAccess() async -> RemindersAccess {
        if access == .notDetermined { access = .granted }
        return access
    }

    func fetchLists() async throws -> [ReminderList] {
        lists
    }

    func fetchReminders() async throws -> [Reminder] {
        reminders
    }

    func setCompleted(_ completed: Bool, reminderID: String) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders[index].isCompleted = completed
    }

    func addReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        toListID listID: String
    ) async throws {
        guard lists.contains(where: { $0.id == listID }) else {
            throw DomainError.notFound
        }
        // `includesTime`은 EventKit의 종일/시각 구분용 — 인메모리 모델은 마감일만 보관한다.
        reminders.append(
            Reminder(
                id: UUID().uuidString,
                title: title,
                isCompleted: false,
                notes: notes,
                dueDate: dueDate,
                listID: listID
            )
        )
    }

    func updateReminder(reminderID: String, title: String, notes: String?) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders[index].title = title
        reminders[index].notes = notes
    }

    func deleteReminder(reminderID: String) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders.remove(at: index)
    }
}
