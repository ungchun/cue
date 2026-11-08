//
//  ReminderEditDraftTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 할일 세부사항 시트의 테스트 가능한 코어 — 편집 상태 → `ReminderChanges` 변환 계약.
/// 핵심은 "손대지 않은 필드는 원래 값 그대로"(가짜 변경 0)와 필드별 매핑.
struct ReminderEditDraftTests {

    private let due = Date(timeIntervalSince1970: 1_700_000_123)   // 초 단위까지 있는 값 — 왕복 손실 감지
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let home = ReminderLocationAlarm(
        title: "집", address: "서울", latitude: 37.5, longitude: 127.0,
        radius: 150, proximity: .leaving
    )

    /// 마감(시각 지정)·사용자화 반복(종료일)·우선순위·위치 알림·메모를 모두 가진 항목.
    private func richReminder() -> Reminder {
        Reminder(
            id: "1", title: "할 일", isCompleted: false, notes: "메모",
            dueDate: due, includesTime: true,
            recurrence: RecurrenceRule(
                frequency: .weekly, interval: 2, weekdays: [2, 4],
                endDate: Date(timeIntervalSince1970: 1_750_000_000)
            ),
            priority: .high, locationAlarm: home, listID: "A"
        )
    }

    private func plainReminder() -> Reminder {
        Reminder(id: "2", title: "단순", isCompleted: false, notes: nil, dueDate: nil, listID: "A")
    }

    // MARK: - 가짜 변경 없음

    @Test(arguments: [true, false])
    func untouchedDraftKeepsEveryField(rich: Bool) {
        let reminder = rich ? richReminder() : plainReminder()
        let draft = ReminderEditDraft(reminder: reminder, now: now)

        #expect(draft.changes(base: reminder) == ReminderChanges(from: reminder))
        #expect(!draft.hasChanges(base: reminder))
    }

    /// 프리셋 반복(매일)도 편집 모델 왕복 없이 그대로 — 원본 객체와 같은 값.
    @Test func untouchedPresetRecurrenceIsPassedThrough() {
        var reminder = richReminder()
        reminder.recurrence = RecurrenceRule(frequency: .daily)
        let draft = ReminderEditDraft(reminder: reminder, now: now)

        #expect(draft.changes(base: reminder).recurrence == reminder.recurrence)
    }

    /// 위치 토글만 켜고 장소를 안 고르면 저장 값이 그대로라 변경으로 치지 않는다.
    @Test func enablingLocationWithoutPlaceIsNotAChange() {
        let reminder = plainReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.isLocationEnabled = true

        #expect(draft.changes(base: reminder).locationAlarm == nil)
        #expect(!draft.hasChanges(base: reminder))
    }

    // MARK: - 필드별 매핑

    @Test func titleAndNotesEditsMap() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.title = "새 제목"
        draft.notes = "새 메모"

        var expected = ReminderChanges(from: reminder)
        expected.title = "새 제목"
        expected.notes = "새 메모"
        #expect(draft.changes(base: reminder) == expected)
        #expect(draft.hasChanges(base: reminder))
    }

    @Test func dueDateEditMapsAndKeepsRecurrence() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        let newDue = due.addingTimeInterval(3_600)
        draft.dueDate = newDue

        let changes = draft.changes(base: reminder)
        #expect(changes.dueDate == newDue)
        #expect(changes.includesTime)
        #expect(changes.recurrence == reminder.recurrence)
    }

    /// 시각만 끄면 날짜는 원래 값 그대로, 시각 지정만 해제.
    @Test func turningTimeOffKeepsDate() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.hasTime = false

        let changes = draft.changes(base: reminder)
        #expect(changes.dueDate == due)
        #expect(!changes.includesTime)
    }

    /// 날짜를 끄면 시각·반복도 함께 해제된다(반복은 날짜 전제).
    @Test func turningDateOffClearsTimeAndRecurrence() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.hasDate = false

        let changes = draft.changes(base: reminder)
        #expect(changes.dueDate == nil)
        #expect(!changes.includesTime)
        #expect(changes.recurrence == nil)
    }

    /// 마감일 없던 항목에 날짜를 켜면 피커 시작값(now)이 마감일이 된다.
    @Test func turningDateOnUsesPickerValue() {
        let reminder = plainReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.hasDate = true

        let changes = draft.changes(base: reminder)
        #expect(changes.dueDate == now)
        #expect(!changes.includesTime)
    }

    @Test func recurrenceEditMaps() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.recurrence = .monthly
        draft.recurrenceEnd = .never

        #expect(draft.changes(base: reminder).recurrence == RecurrenceRule(frequency: .monthly))
    }

    @Test func listAndPriorityEditsMap() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.listID = "B"
        draft.priority = ReminderPriority.none

        let changes = draft.changes(base: reminder)
        #expect(changes.listID == "B")
        #expect(changes.priority == ReminderPriority.none)
    }

    // MARK: - 위치 알림

    @Test func turningLocationOffClearsAlarm() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.isLocationEnabled = false

        #expect(draft.changes(base: reminder).locationAlarm == nil)
    }

    @Test func proximityEditMaps() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.proximity = .arriving

        var expected = home
        expected.proximity = .arriving
        #expect(draft.changes(base: reminder).locationAlarm == expected)
    }

    /// 장소를 바꾸면 좌표·이름·주소는 새 값, 반경은 기존 값 유지.
    @Test func selectingPlaceKeepsRadius() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)

        let accepted = draft.selectLocation(EventEditDraft.Location(
            title: "회사", address: "판교", latitude: 37.4, longitude: 127.1
        ))

        #expect(accepted)
        #expect(draft.changes(base: reminder).locationAlarm == ReminderLocationAlarm(
            title: "회사", address: "판교", latitude: 37.4, longitude: 127.1,
            radius: 150, proximity: .leaving
        ))
    }

    /// 위치가 없던 항목에 켜고 장소를 고르면 새 알림(기본 반경·도착).
    @Test func enablingLocationWithPlaceAddsAlarm() {
        let reminder = plainReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)
        draft.isLocationEnabled = true
        draft.selectLocation(EventEditDraft.Location(title: "회사", latitude: 37.4, longitude: 127.1))

        #expect(draft.changes(base: reminder).locationAlarm == ReminderLocationAlarm(
            title: "회사", address: nil, latitude: 37.4, longitude: 127.1,
            radius: nil, proximity: .arriving
        ))
    }

    /// 좌표 없는 선택(이름만 입력)은 거절 — 기존 장소가 그대로 남는다.
    @Test func selectingPlaceWithoutCoordinateIsRejected() {
        let reminder = richReminder()
        var draft = ReminderEditDraft(reminder: reminder, now: now)

        let accepted = draft.selectLocation(EventEditDraft.Location(title: "어딘가"))

        #expect(!accepted)
        #expect(draft.changes(base: reminder).locationAlarm == home)
    }

    // MARK: - 생성 경로

    /// 생성 드래프트의 저장 값 — 날짜를 끄면 시각·반복을 버린다.
    @Test func newDraftDropsTimeAndRecurrenceWithoutDate() {
        var draft = ReminderEditDraft(
            title: "새 할 일", notes: "",
            dueDate: due, includesTime: true, recurrence: RecurrenceRule(frequency: .daily),
            now: now
        )
        #expect(draft.effectiveDueDate == due)
        #expect(draft.effectiveIncludesTime)
        #expect(draft.effectiveRecurrence == RecurrenceRule(frequency: .daily))

        draft.hasDate = false

        #expect(draft.effectiveDueDate == nil)
        #expect(!draft.effectiveIncludesTime)
        #expect(draft.effectiveRecurrence == nil)
    }

    /// 생성 드래프트의 목록 — 일정 탭 + 시트는 기본 목록을 넘기고, 할일 탭은 안 넘겨 빈 값.
    @Test func newDraftKeepsGivenListOrStartsEmpty() {
        let withList = ReminderEditDraft(
            title: "", notes: "", dueDate: nil, includesTime: false, recurrence: nil,
            listID: "list-b", now: now
        )
        let withoutList = ReminderEditDraft(
            title: "", notes: "", dueDate: nil, includesTime: false, recurrence: nil, now: now
        )

        #expect(withList.listID == "list-b")
        #expect(withoutList.listID == "")
    }
}
