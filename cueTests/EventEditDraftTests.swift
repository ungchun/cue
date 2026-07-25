//
//  EventEditDraftTests.swift
//  cueTests
//

import EventKit
import Foundation
import Testing
@testable import cue

/// 자체 이벤트 편집 시트의 테스트 가능한 코어 — 드래프트 시간 로직과
/// EventKit(반복 규칙·알림) 매핑 계약. 뷰(EventDetailSheet)는 이 값들만 소비한다.
struct EventEditDraftTests {

    private let calendar = Calendar.current

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        DateComponents(calendar: calendar, year: y, month: mo, day: d, hour: h, minute: mi).date!
    }

    // MARK: - 신규 기본값

    /// 신규 이벤트는 다음 정시부터 1시간 — Apple 캘린더 신규 시트와 동일.
    @Test func newDraftStartsAtNextFullHourWithOneHourDuration() {
        let draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 23))

        #expect(draft.start == date(2026, 7, 25, 15, 0))
        #expect(draft.end == date(2026, 7, 25, 16, 0))
        #expect(!draft.isAllDay)
    }

    /// 정각이면 그 시각 그대로 시작.
    @Test func newDraftOnExactHourKeepsThatHour() {
        let draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 9, 0))
        #expect(draft.start == date(2026, 7, 25, 9, 0))
    }

    // MARK: - 시작/종료 시간 로직

    /// 시작을 옮기면 기존 지속시간을 유지한 채 종료가 따라간다 — Apple 캘린더와 동일.
    @Test func movingStartPreservesDuration() {
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 10, 0))
        draft.setEnd(date(2026, 7, 25, 12, 0))          // 지속 2시간

        draft.setStart(date(2026, 7, 26, 9, 0))

        #expect(draft.end == date(2026, 7, 26, 11, 0))  // 2시간 유지
    }

    /// 종료를 시작 이전으로 내리면 시작 시각으로 클램프 — 음수 길이 금지.
    @Test func settingEndBeforeStartClampsToStart() {
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 10, 0))

        draft.setEnd(date(2026, 7, 25, 9, 0))

        #expect(draft.end == draft.start)
    }

    // MARK: - 반복 옵션 ↔ EKRecurrenceRule

    @Test func recurrenceOptionMapsFromRules() {
        func rule(_ f: EKRecurrenceFrequency, _ interval: Int) -> EKRecurrenceRule {
            EKRecurrenceRule(recurrenceWith: f, interval: interval, end: nil)
        }

        #expect(EventEditDraft.Recurrence(rules: nil) == EventEditDraft.Recurrence.none)
        #expect(EventEditDraft.Recurrence(rules: [rule(.daily, 1)]) == .daily)
        #expect(EventEditDraft.Recurrence(rules: [rule(.weekly, 1)]) == .weekly)
        #expect(EventEditDraft.Recurrence(rules: [rule(.weekly, 2)]) == .biweekly)
        #expect(EventEditDraft.Recurrence(rules: [rule(.monthly, 1)]) == .monthly)
        #expect(EventEditDraft.Recurrence(rules: [rule(.yearly, 1)]) == .yearly)
        // 프리셋 밖(3주마다·요일 지정 등)은 custom — 저장 시 기존 규칙을 건드리지 않는다.
        #expect(EventEditDraft.Recurrence(rules: [rule(.weekly, 3)]) == .custom)
    }

    @Test func recurrenceOptionProducesRules() throws {
        #expect(EventEditDraft.Recurrence.none.rule() == nil)
        #expect(EventEditDraft.Recurrence.custom.rule() == nil)   // custom은 규칙 생성 없음(보존 신호)

        let biweekly = try #require(EventEditDraft.Recurrence.biweekly.rule())
        #expect(biweekly.frequency == .weekly)
        #expect(biweekly.interval == 2)

        let yearly = try #require(EventEditDraft.Recurrence.yearly.rule())
        #expect(yearly.frequency == .yearly)
        #expect(yearly.interval == 1)
    }

    // MARK: - 알림 옵션 ↔ 상대 오프셋

    @Test func alarmOptionMapsFromRelativeOffset() {
        #expect(EventEditDraft.Alarm(alarms: nil) == EventEditDraft.Alarm.none)
        #expect(EventEditDraft.Alarm(alarms: [EKAlarm(relativeOffset: 0)]) == .atTime)
        #expect(EventEditDraft.Alarm(alarms: [EKAlarm(relativeOffset: -300)]) == .minutesBefore(5))
        #expect(EventEditDraft.Alarm(alarms: [EKAlarm(relativeOffset: -3600)]) == .minutesBefore(60))
        #expect(EventEditDraft.Alarm(alarms: [EKAlarm(relativeOffset: -86_400)]) == .minutesBefore(1_440))
        // 프리셋 밖 오프셋(-7분 등)은 custom — 저장 시 기존 알림을 보존한다.
        #expect(EventEditDraft.Alarm(alarms: [EKAlarm(relativeOffset: -420)]) == .custom)
    }

    @Test func alarmOptionProducesRelativeOffset() {
        #expect(EventEditDraft.Alarm.none.relativeOffset == nil)
        #expect(EventEditDraft.Alarm.atTime.relativeOffset == 0)
        #expect(EventEditDraft.Alarm.minutesBefore(30).relativeOffset == -1800)
        #expect(EventEditDraft.Alarm.custom.relativeOffset == nil)
    }

    // MARK: - EKEvent 읽기/쓰기

    /// 기존 EKEvent → 드래프트 스냅샷. (EKEventStore 인스턴스 생성은 권한과 무관.)
    @Test func readsDraftFromEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "회의"
        event.location = "3층"
        event.isAllDay = false
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.notes = "자료 지참"
        event.url = URL(string: "https://example.com")
        event.addAlarm(EKAlarm(relativeOffset: -600))

        let draft = EventEditDraft(event: event)

        #expect(draft.title == "회의")
        #expect(draft.location == "3층")
        #expect(draft.start == date(2026, 7, 25, 10, 0))
        #expect(draft.end == date(2026, 7, 25, 11, 0))
        #expect(draft.notes == "자료 지참")
        #expect(draft.urlString == "https://example.com")
        #expect(draft.alarm == .minutesBefore(10))
        #expect(draft.recurrence == EventEditDraft.Recurrence.none)
    }

    /// 드래프트 → EKEvent 반영. 빈 문자열 필드는 nil로 정리한다.
    @Test func appliesDraftToEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 0))
        draft.title = "  점심  "
        draft.location = ""
        draft.notes = ""
        draft.urlString = "https://cue.app"
        draft.alarm = .minutesBefore(15)
        draft.recurrence = .daily

        draft.apply(to: event)

        #expect(event.title == "점심")                    // 제목은 트리밍
        #expect(event.location == nil)                    // 빈 필드는 nil
        #expect(event.notes == nil)
        #expect(event.url?.absoluteString == "https://cue.app")
        #expect(event.alarms?.map(\.relativeOffset) == [-900])
        #expect(event.recurrenceRules?.first?.frequency == .daily)
    }

    /// custom 반복·알림은 기존 값을 보존한다 — 사용자가 안 건드린 고급 설정 파괴 금지.
    @Test func applyingCustomOptionsPreservesExistingRulesAndAlarms() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let exotic = EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 3,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.monday)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil
        )
        event.addRecurrenceRule(exotic)
        event.addAlarm(EKAlarm(relativeOffset: -420))
        var draft = EventEditDraft(event: event)
        #expect(draft.recurrence == .custom)
        #expect(draft.alarm == .custom)

        draft.title = "바뀐 제목"
        draft.apply(to: event)

        #expect(event.recurrenceRules?.first?.interval == 3)                 // 보존
        #expect(event.alarms?.map(\.relativeOffset) == [-420])               // 보존
    }

    /// custom → 프리셋으로 바꾸면 기존 규칙·알림을 교체한다.
    @Test func switchingAwayFromCustomReplacesRulesAndAlarms() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 3, end: nil))
        event.addAlarm(EKAlarm(relativeOffset: -420))
        var draft = EventEditDraft(event: event)

        draft.recurrence = .monthly
        draft.alarm = EventEditDraft.Alarm.none
        draft.apply(to: event)

        #expect(event.recurrenceRules?.count == 1)
        #expect(event.recurrenceRules?.first?.frequency == .monthly)
        #expect(event.recurrenceRules?.first?.interval == 1)
        #expect(event.alarms == nil || event.alarms?.isEmpty == true)
    }

    /// 종일 전환 시 시각 성분과 무관하게 isAllDay만 반영 — 날짜는 그대로.
    @Test func applyKeepsDatesWhenTogglingAllDay() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 0))
        draft.isAllDay = true

        draft.apply(to: event)

        #expect(event.isAllDay)
        #expect(event.startDate == draft.start)
    }
}
