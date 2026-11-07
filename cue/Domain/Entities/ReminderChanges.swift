//
//  ReminderChanges.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 수정 요청 — 편집 가능한 **전체 상태**를 한 덩어리로 들고 다닌다.
///
/// 이니셜라이저에 기본값을 두지 않는다: 필드를 빠뜨리면 컴파일 에러가 나게 해, 생략된 값이
/// 조용히 nil(=삭제)로 저장되는 부류의 버그(인라인 편집이 반복을 지우던 문제)를 막는다.
/// 몇 개만 바꾸는 호출부는 `init(from:)`으로 현재 값을 복사한 뒤 바꿀 필드만 덮어쓴다.
struct ReminderChanges: Equatable, Sendable {
    var title: String
    /// nil이면 메모를 비운다.
    var notes: String?
    /// nil이면 마감일을 지운다(반복·시각 지정도 함께 해제된다).
    var dueDate: Date?
    var includesTime: Bool
    /// nil이면 반복을 지운다.
    var recurrence: RecurrenceRule?
    var priority: ReminderPriority
    /// nil이면 위치 알림을 지운다.
    var locationAlarm: ReminderLocationAlarm?
    /// 속할 리스트 — 현재와 다르면 그 리스트로 옮긴다.
    var listID: String

    init(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        recurrence: RecurrenceRule?,
        priority: ReminderPriority,
        locationAlarm: ReminderLocationAlarm?,
        listID: String
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.includesTime = includesTime
        self.recurrence = recurrence
        self.priority = priority
        self.locationAlarm = locationAlarm
        self.listID = listID
    }

    /// 현재 항목의 편집 가능한 값을 그대로 복사한다 — 일부 필드만 바꾸는 경로의 출발점.
    init(from reminder: Reminder) {
        self.init(
            title: reminder.title,
            notes: reminder.notes,
            dueDate: reminder.dueDate,
            includesTime: reminder.includesTime,
            recurrence: reminder.recurrence,
            priority: reminder.priority,
            locationAlarm: reminder.locationAlarm,
            listID: reminder.listID
        )
    }
}
