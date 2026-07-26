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

    /// 상태-전용 조회 — 프롬프트를 절대 띄우지 않는다(앱 시작 프리페치 경로).
    func currentAccess() async -> RemindersAccess {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func fetchLists() async throws -> [ReminderList] {
        let defaultListID = store.defaultCalendarForNewReminders()?.calendarIdentifier
        return store.calendars(for: .reminder).map { ReminderMapper.toList($0, defaultListID: defaultListID) }
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

    @discardableResult
    func addReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        recurrence: RecurrenceRule?,
        toListID listID: String
    ) async throws -> Reminder {
        guard let calendar = store.calendars(for: .reminder)
            .first(where: { $0.calendarIdentifier == listID }) else {
            throw DomainError.notFound
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.notes = notes
        reminder.calendar = calendar
        // 반복은 마감일이 있을 때만 — EventKit 반복 미리알림은 마감일 기준으로 전개된다.
        if dueDate != nil, let rule = ReminderMapper.toEKRecurrenceRule(recurrence) {
            reminder.addRecurrenceRule(rule)
        }
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
        // 저장 직후의 EKReminder는 실제 id(calendarItemIdentifier)·creationDate를 갖는다 —
        // 호출자가 재조회 없이 곧장 로컬 목록에 꽂을 수 있는 완성 엔티티로 돌려준다.
        return ReminderMapper.toReminder(reminder)
    }

    @discardableResult
    func updateReminder(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        recurrence: RecurrenceRule?
    ) async throws -> Reminder {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        reminder.title = title
        reminder.notes = notes
        // 반복은 **실제로 바뀌었을 때만** 재기록 — 동치면 그대로 둬서 도메인이 표현 못 하는
        // 원본 세부(횟수 종료 등)를 깎지 않는다(미리알림 앱에서 만든 규칙 보존).
        let effectiveRecurrence = dueDate != nil ? recurrence : nil
        if !ReminderMapper.isEquivalentRecurrence(reminder.recurrenceRules?.first, to: effectiveRecurrence) {
            (reminder.recurrenceRules ?? []).forEach(reminder.removeRecurrenceRule)
            if let rule = ReminderMapper.toEKRecurrenceRule(effectiveRecurrence) {
                reminder.addRecurrenceRule(rule)
            }
        }
        // 알람은 cue가 관리하는 **마감 시각 절대 알람만** 떼고 다시 단다 — 사용자가 미리알림
        // 앱에서 단 위치·상대·추가 알람은 보존(마감일 변경 시 마감 알람 시각만 따라간다).
        for alarm in (reminder.alarms ?? []) where ReminderMapper.isCueManagedDueAlarm(alarm) {
            reminder.removeAlarm(alarm)
        }
        if let dueDate {
            let fields: Set<Calendar.Component> = includesTime
                ? [.year, .month, .day, .hour, .minute]
                : [.year, .month, .day]
            reminder.dueDateComponents = Calendar.current.dateComponents(fields, from: dueDate)
            if includesTime {
                reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
            }
        } else {
            reminder.dueDateComponents = nil
        }
        try store.save(reminder, commit: true)
        return ReminderMapper.toReminder(reminder)
    }

    func deleteReminder(reminderID: String) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        try store.remove(reminder, commit: true)
    }

    func moveReminder(reminderID: String, toListID listID: String) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        guard let calendar = store.calendars(for: .reminder)
            .first(where: { $0.calendarIdentifier == listID }) else {
            throw DomainError.notFound
        }
        reminder.calendar = calendar
        try store.save(reminder, commit: true)
    }

    // MARK: - Lists (calendars)

    func addList(title: String, colorHex: String?) async throws -> String {
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = title
        if let cgColor = Self.cgColor(fromHex: colorHex) {
            calendar.cgColor = cgColor
        }
        // 합의된 정책: iCloud 우선, 없으면 사용자의 기본 미리알림 리스트 source로 fallback,
        // 그것도 없으면 reminders를 지원하는 첫 source.
        guard let source = pickListSource() else {
            throw DomainError.validation(String(localized: "No available source to create a list."))
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar.calendarIdentifier
    }

    func updateList(listID: String, title: String, colorHex: String?) async throws {
        guard let calendar = store.calendar(withIdentifier: listID) else {
            throw DomainError.notFound
        }
        calendar.title = title
        // colorHex가 nil이면 색을 건드리지 않는다 — "비우기"가 아니라 "변경 없음".
        if let cgColor = Self.cgColor(fromHex: colorHex) {
            calendar.cgColor = cgColor
        }
        try store.saveCalendar(calendar, commit: true)
    }

    func deleteList(listID: String) async throws {
        guard let calendar = store.calendar(withIdentifier: listID) else {
            throw DomainError.notFound
        }
        try store.removeCalendar(calendar, commit: true)
    }

    /// 새 리스트가 들어갈 EKSource — 우선순위는 `ReminderListSourcePicker`(순수 정책)가 정한다:
    /// 기본 미리알림 리스트의 source → 미리알림을 가진 iCloud → 미리알림을 가진 아무 계정.
    /// 이름("iCloud") 매칭으로 고르면 iCloud 미리알림 동기화가 꺼진 기기에서 미지원 계정을
    /// 찍어 저장이 실패한다 — 능력 기준으로만 고르고, 지원 계정이 없으면 nil(호출처가 안내).
    private func pickListSource() -> EKSource? {
        let sources = store.sources
        let candidates = sources.map { source in
            ReminderListSourcePicker.Candidate(
                id: source.sourceIdentifier,
                isICloud: source.sourceType == .calDAV
                    && source.title.lowercased().contains("icloud"),
                hasReminderCalendars: !source.calendars(for: .reminder).isEmpty
            )
        }
        let defaultSourceID = store.defaultCalendarForNewReminders()?.source?.sourceIdentifier
        guard let pickedID = ReminderListSourcePicker.pick(
            from: candidates, defaultSourceID: defaultSourceID
        ) else { return nil }
        return sources.first { $0.sourceIdentifier == pickedID }
    }

    /// `EKEventStoreChanged`는 미리알림·캘린더 변경 모두에 발송되는 공통 노티 — reminders
    /// 측은 그 중 미리알림 변경에 대응한다. 구독자 측에서 stream을 종료해도 안에서 만든
    /// Task가 자동 cancel되도록 `onTermination`에 연결.
    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                    if Task.isCancelled { break }
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// "#RRGGBB" → sRGB `CGColor`. 잘못된 포맷이면 nil.
    /// Mapper의 hex 추출과 역방향 대칭 — sRGB 가정.
    private static func cgColor(fromHex hex: String?) -> CGColor? {
        guard var s = hex else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xff) / 255
        let g = CGFloat((v >> 8) & 0xff) / 255
        let b = CGFloat(v & 0xff) / 255
        return CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
