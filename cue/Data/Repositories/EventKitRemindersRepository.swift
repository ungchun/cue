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
    /// 이번 실행에서 프롬프트로 허용받았는지. `authorizationStatus`는 허용 직후에도 같은 프로세스에선
    /// `.notDetermined`를 계속 돌려줘(2026-11-09 QA 실측) 월 캘린더가 재실행 전까지 빈 채로 남았다.
    /// 설정에서 권한을 끄면 iOS가 앱을 종료하므로 이 값이 낡을 일은 없다.
    private var grantedThisLaunch = false

    func requestAccess() async -> RemindersAccess {
        if grantedThisLaunch { return .granted }
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess:
            return .granted
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToReminders()
                grantedThisLaunch = granted
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
        if grantedThisLaunch { return .granted }
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
    func updateReminder(reminderID: String, changes: ReminderChanges) async throws -> Reminder {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        // 리스트 이동 대상은 쓰기 가능한 리스트만 — 읽기 전용(구독·공유 읽기) 리스트는 없는
        // 리스트와 같게 취급한다. 다른 필드를 건드리기 전에 확인해 반쯤 바뀐 상태를 만들지 않는다.
        var targetCalendar: EKCalendar?
        if changes.listID != reminder.calendar.calendarIdentifier {
            guard let calendar = store.calendars(for: .reminder).first(where: {
                $0.calendarIdentifier == changes.listID && $0.allowsContentModifications
            }) else {
                throw DomainError.notFound
            }
            targetCalendar = calendar
        }
        ReminderMapper.apply(changes, to: reminder)
        if let targetCalendar {
            reminder.calendar = targetCalendar
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

    /// EventKit엔 할일 회차 삭제(EKSpan)가 없다. 미리 알림 앱의 "이 미리 알림만 삭제"는 같은 항목의
    /// 마감만 다음 회차로 옮긴다 — 완료 사본도 삭제 기록도 남기지 않는다(2026-11-09 실측). 그대로 따라 한다.
    /// 다음 회차가 없으면(반복 아님·마지막 회차) 항목을 지운다.
    func deleteOccurrence(reminderID: String) async throws {
        guard let reminder = store.calendarItem(withIdentifier: reminderID) as? EKReminder else {
            throw DomainError.notFound
        }
        let current = ReminderMapper.toReminder(reminder)
        guard let due = current.dueDate, let next = current.nextOccurrence(),
              var components = reminder.dueDateComponents else {
            try store.remove(reminder, commit: true)
            return
        }
        // 날짜만 바꾼다 — 시·분·시간대는 그대로라 시각 지정 마감의 시각이 유지된다.
        let day = Calendar.current.dateComponents([.year, .month, .day], from: next)
        components.year = day.year
        components.month = day.month
        components.day = day.day
        reminder.dueDateComponents = components
        // 절대 시각 알람(cue가 다는 마감 알람 포함)은 같은 만큼 민다 — 안 밀면 지난 시각에 남아 울리지 않는다.
        // 상대 오프셋 알람은 마감을 따라가고, 위치 알람은 시각이 없다.
        let shift = next.timeIntervalSince(due)
        for alarm in reminder.alarms ?? [] where alarm.structuredLocation == nil {
            if let date = alarm.absoluteDate {
                alarm.absoluteDate = date.addingTimeInterval(shift)
            }
        }
        try store.save(reminder, commit: true)
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
