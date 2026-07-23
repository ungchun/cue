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
    /// 변경 신호 stream. single-consumer 가정(테스트·ViewModel 1쌍). 다중 구독이 필요하면
    /// EventKit 구현처럼 NotificationCenter 패턴으로 바꾼다.
    private let changesStream: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation

    init(
        access: RemindersAccess = .granted,
        lists: [ReminderList] = [],
        reminders: [Reminder] = []
    ) {
        let (stream, continuation) = AsyncStream<Void>.makeStream()
        self.changesStream = stream
        self.changesContinuation = continuation
        self.access = access
        self.lists = lists
        self.reminders = reminders
    }

    nonisolated func changes() -> AsyncStream<Void> { changesStream }

    /// 테스트 헬퍼 — 변경 신호를 한 번 emit한다. 실 EventKit 구현은 NotificationCenter가
    /// 자동으로 emit하므로 외부에서 호출할 필요가 없다.
    func emitChange() {
        changesContinuation.yield(())
    }

    func requestAccess() async -> RemindersAccess {
        if access == .notDetermined { access = .granted }
        return access
    }

    /// 프롬프트 시뮬레이션(미결정→허용) 없이 상태 그대로 — 프리페치 가드 테스트의 관측점.
    func currentAccess() async -> RemindersAccess {
        access
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
        reminders.append(
            Reminder(
                id: UUID().uuidString,
                title: title,
                isCompleted: false,
                notes: notes,
                dueDate: dueDate,
                includesTime: includesTime,
                listID: listID
            )
        )
    }

    func updateReminder(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool
    ) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders[index].title = title
        reminders[index].notes = notes
        reminders[index].dueDate = dueDate
        reminders[index].includesTime = includesTime
    }

    func moveReminder(reminderID: String, toListID listID: String) async throws {
        guard lists.contains(where: { $0.id == listID }) else {
            throw DomainError.notFound
        }
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders[index].listID = listID
    }

    func deleteReminder(reminderID: String) async throws {
        guard let index = reminders.firstIndex(where: { $0.id == reminderID }) else {
            throw DomainError.notFound
        }
        reminders.remove(at: index)
    }

    func addList(title: String, colorHex: String?) async throws -> String {
        let id = UUID().uuidString
        lists.append(ReminderList(id: id, title: title, colorHex: colorHex))
        return id
    }

    func updateList(listID: String, title: String, colorHex: String?) async throws {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else {
            throw DomainError.notFound
        }
        lists[index].title = title
        // EventKit 구현과 같은 의미론: nil이면 색을 건드리지 않음.
        if let colorHex {
            lists[index].colorHex = colorHex
        }
    }

    func deleteList(listID: String) async throws {
        guard let index = lists.firstIndex(where: { $0.id == listID }) else {
            throw DomainError.notFound
        }
        lists.remove(at: index)
        // EventKit 동작과 동일하게 리스트 안의 항목도 함께 제거.
        reminders.removeAll { $0.listID == listID }
    }
}
