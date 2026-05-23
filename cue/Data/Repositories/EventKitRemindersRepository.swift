//
//  EventKitRemindersRepository.swift
//  cue / Data
//

import EventKit
import Foundation

/// `RemindersRepository`의 EventKit 구현 — iOS "미리 알림" 앱의 실제 데이터를 읽고 쓴다.
///
/// 비-Sendable인 `EKEventStore`를 `actor`로 가둬 `Sendable`을 만족시킨다
/// (`InMemoryRemindersRepository`와 같은 방식). EventKit은 메인 스레드를 요구하지
/// 않으므로 `@MainActor` 대신 `actor`가 맞다. EventKit·권한에 직접 붙는 I/O 경계 글루.
actor EventKitRemindersRepository: RemindersRepository {
    private let store = EKEventStore()

    func requestAccess() async -> RemindersAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToReminders()
                return granted ? .granted : .denied
            } catch {
                return .denied
            }
        default:
            // .denied, .restricted 등
            return .denied
        }
    }

    func fetchLists() async throws -> [ReminderList] {
        store.calendars(for: .reminder).map(ReminderMapper.toList)
    }

    func fetchReminders() async throws -> [Reminder] {
        let predicate = store.predicateForReminders(in: nil)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { ekReminders in
                let reminders = (ekReminders ?? []).map(ReminderMapper.toReminder)
                continuation.resume(returning: reminders)
            }
        }
    }

    func setCompleted(_ completed: Bool, reminderID: String) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        reminder.isCompleted = completed
        try store.save(reminder, commit: true)
    }

    func addReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        toListID listID: String
    ) async throws {
        guard let calendar = store.calendars(for: .reminder)
            .first(where: { $0.calendarIdentifier == listID }) else {
            throw DomainError.notFound
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar
        if let dueDate {
            // 시간이 없으면 [년·월·일]만 — EventKit은 이를 "종일" 마감으로 본다.
            let fields: Set<Calendar.Component> = includesTime
                ? [.year, .month, .day, .hour, .minute]
                : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: dueDate)
            // 마감일만으로는 알림이 울리지 않는다 — 시간이 있으면 알람을 함께 단다.
            if includesTime {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        }
        try store.save(reminder, commit: true)
    }

    func updateReminder(reminderID: String, title: String, notes: String?) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        reminder.title = title
        reminder.notes = notes
        try store.save(reminder, commit: true)
    }

    func deleteReminder(reminderID: String) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        try store.remove(reminder, commit: true)
    }
}
