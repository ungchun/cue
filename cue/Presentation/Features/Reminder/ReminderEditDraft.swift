//
//  ReminderEditDraft.swift
//  cue / Presentation
//

import Foundation

/// 할일 세부사항 시트의 편집 상태 — 뷰(ReminderEditForm)는 이 값만 바인딩하고, 저장 값
/// (`ReminderChanges`) 변환은 여기서 한다(뷰 밖이라 테스트 가능).
///
/// 핵심 계약: 사용자가 건드리지 않은 필드는 원래 값을 **그대로** 돌려준다. 그래서 편집 UI
/// 모델(반복·날짜 토글)로 한 번 거쳐 다시 만든 값 대신, 바뀐 필드 묶음만 덮어쓴다 —
/// 손대지 않은 마감일·반복이 변환 왕복으로 조금이라도 달라져 저장되는 일을 막는다.
struct ReminderEditDraft: Equatable {
    var title: String
    var notes: String
    var hasDate: Bool
    var hasTime: Bool
    /// 날짜가 꺼져 있을 때도 피커 표시용 값을 들고 있다(켜면 이 값에서 시작).
    var dueDate: Date
    var recurrence: EventEditDraft.Recurrence
    var recurrenceEnd: EventEditDraft.RecurrenceEnd
    var isLocationEnabled: Bool
    /// 고른 장소(반경 포함). 도착/출발은 장소 없이도 고를 수 있게 `proximity`로 따로 둔다.
    var location: ReminderLocationAlarm?
    var proximity: ReminderLocationAlarm.Proximity
    var listID: String
    var priority: ReminderPriority

    /// 기존 항목 편집 — 현재 값으로 채운다. `now`는 마감일이 없을 때의 피커 시작값.
    init(reminder: Reminder, now: Date = .now) {
        title = reminder.title
        notes = reminder.notes ?? ""
        hasDate = reminder.dueDate != nil
        hasTime = reminder.dueDate != nil && reminder.includesTime
        dueDate = reminder.dueDate ?? now
        recurrence = .init(reminderRule: reminder.recurrence)
        recurrenceEnd = .init(reminderRule: reminder.recurrence)
        isLocationEnabled = reminder.locationAlarm != nil
        location = reminder.locationAlarm
        proximity = reminder.locationAlarm?.proximity ?? .arriving
        listID = reminder.listID
        priority = reminder.priority
    }

    /// 신규 생성 — 생성 경로(add)는 리스트·우선순위·위치를 받지 않아 폼도 그 행을 숨긴다.
    init(
        title: String,
        notes: String,
        dueDate: Date?,
        includesTime: Bool,
        recurrence: RecurrenceRule?,
        now: Date = .now
    ) {
        self.title = title
        self.notes = notes
        hasDate = dueDate != nil
        hasTime = dueDate != nil && includesTime
        self.dueDate = dueDate ?? now
        self.recurrence = .init(reminderRule: recurrence)
        recurrenceEnd = .init(reminderRule: recurrence)
        isLocationEnabled = false
        location = nil
        proximity = .arriving
        listID = ""
        priority = ReminderPriority.none
    }

    // MARK: - 파생값

    /// 저장할 마감일 — 날짜가 꺼져 있으면 nil.
    var effectiveDueDate: Date? { hasDate ? dueDate : nil }

    /// 시각 지정은 날짜 전제.
    var effectiveIncludesTime: Bool { hasDate && hasTime }

    /// 반복은 날짜 전제 — 날짜를 끄면 함께 버린다(Apple 미리 알림과 동일).
    var effectiveRecurrence: RecurrenceRule? {
        hasDate ? recurrence.reminderRule(endingOn: recurrenceEnd) : nil
    }

    /// 저장할 위치 알림 — 토글이 꺼졌거나 장소를 아직 안 골랐으면 nil.
    var effectiveLocationAlarm: ReminderLocationAlarm? {
        guard isLocationEnabled, var alarm = location else { return nil }
        alarm.proximity = proximity
        return alarm
    }

    // MARK: - 편집

    /// 위치 선택 시트 결과 반영. 위치 알림은 좌표가 있어야 울리므로 좌표 없는 선택(이름만
    /// 입력)은 거절한다(false). 기존 반경은 장소를 바꿔도 유지한다.
    @discardableResult
    mutating func selectLocation(_ selected: EventEditDraft.Location) -> Bool {
        guard let latitude = selected.latitude, let longitude = selected.longitude else { return false }
        location = ReminderLocationAlarm(
            title: selected.title,
            address: selected.address,
            latitude: latitude,
            longitude: longitude,
            radius: location?.radius,
            proximity: proximity
        )
        return true
    }

    // MARK: - 저장 값

    /// `base`(편집을 시작한 항목) 대비 바뀐 묶음만 덮어쓴 전체 상태.
    func changes(base: Reminder) -> ReminderChanges {
        var changes = ReminderChanges(from: base)
        changes.title = title
        if notes != (base.notes ?? "") {
            changes.notes = notes
        }
        // 마감일·시각 — 날짜 켬/끔, 날짜 변경, 시각 켬/끔 중 하나라도 있을 때만 다시 쓴다.
        let dateChanged = effectiveDueDate != base.dueDate
            || (hasDate && hasTime != base.includesTime)
        if dateChanged {
            changes.dueDate = effectiveDueDate
            changes.includesTime = effectiveIncludesTime
        }
        // 반복 — 날짜를 끄면 해제, 아니면 편집 모델이 원래와 다를 때만 다시 만든다.
        if !hasDate {
            if base.dueDate != nil { changes.recurrence = nil }
        } else if recurrence != EventEditDraft.Recurrence(reminderRule: base.recurrence)
                    || recurrenceEnd != EventEditDraft.RecurrenceEnd(reminderRule: base.recurrence) {
            changes.recurrence = effectiveRecurrence
        }
        changes.locationAlarm = effectiveLocationAlarm
        changes.listID = listID
        changes.priority = priority
        return changes
    }

    /// 저장하면 실제로 무언가 바뀌는지 — X의 폐기 확인 여부. (토글만 켜고 장소를 안 고른
    /// 위치처럼 저장 값에 영향 없는 조작은 변경으로 치지 않는다.)
    func hasChanges(base: Reminder) -> Bool {
        changes(base: base) != ReminderChanges(from: base)
    }
}
