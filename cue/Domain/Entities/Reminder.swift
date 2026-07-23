//
//  Reminder.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 항목 하나 — iOS "미리 알림" 앱의 한 항목에 대응하는 도메인 엔티티.
///
/// `includesTime` — EventKit의 `dueDateComponents`에 시·분이 들어있는지(=시각 지정),
/// 없으면 종일(date-only). 도메인이 직접 이 구분을 들고 있어야 수정 시 시트 토글을
/// 정확히 복원할 수 있다. 기본값 false는 마감일이 없는 항목/단순 생성을 위한 편의.
struct Reminder: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var title: String
    var isCompleted: Bool
    var notes: String?
    var dueDate: Date?
    var includesTime: Bool = false
    /// 반복 주기. nil이면 일회성 항목. EventKit `recurrenceRules`의 첫 규칙만 매핑한다.
    var recurrence: RecurrenceRule? = nil
    /// 생성 시각(EventKit `creationDate`). 시스템 필터(전체·예정)의 "추가한 순서" 정렬 기준.
    /// nil이면 정렬에서 맨 뒤로 보낸다(미리 알림 앱과 동일하게 가장 나중에 추가된 것 취급).
    var creationDate: Date? = nil
    let listID: String
}
