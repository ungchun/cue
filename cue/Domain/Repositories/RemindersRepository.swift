//
//  RemindersRepository.swift
//  cue / Domain
//

import Foundation

/// iOS "미리 알림" 저장소 추상화 — Domain이 소유하는 프로토콜. 구현은 Data 계층(EventKit).
///
/// Domain은 EventKit 같은 세부 기술을 알지 못한다. 이 경계 덕분에
/// 저장 방식이 바뀌어도 Domain/Presentation은 영향받지 않는다.
protocol RemindersRepository: Sendable {
    /// 접근 권한을 요청한다 (필요 시 시스템 프롬프트). 결과 상태를 돌려준다.
    func requestAccess() async -> RemindersAccess
    /// 모든 미리 알림 리스트.
    func fetchLists() async throws -> [ReminderList]
    /// 모든 리스트의 미리 알림 항목 전체.
    func fetchReminders() async throws -> [Reminder]
    /// 항목의 완료 상태를 설정한다.
    func setCompleted(_ completed: Bool, reminderID: String) async throws
    /// 리스트에 새 항목을 추가한다. `notes`가 nil이면 메모 없이 만든다.
    /// `dueDate`가 nil이면 마감일 없이, `includesTime`이 false면 시간 없는(종일) 마감으로 만든다.
    func addReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        toListID listID: String
    ) async throws
    /// 기존 항목의 제목·메모를 갱신한다. `notes`가 nil이면 메모를 비운다.
    func updateReminder(reminderID: String, title: String, notes: String?) async throws
    /// 항목을 삭제한다.
    func deleteReminder(reminderID: String) async throws
}
