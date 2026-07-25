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
        // 프리셋 밖이지만 표현 가능한 규칙(3주마다)은 편집 가능한 custom 페이로드로.
        #expect(EventEditDraft.Recurrence(rules: [rule(.weekly, 3)])
                == .custom(.init(frequency: .weekly, interval: 3)))
    }

    @Test func recurrenceOptionProducesRules() throws {
        #expect(EventEditDraft.Recurrence.none.rule(endingOn: .never) == nil)
        #expect(EventEditDraft.Recurrence.foreign.rule(endingOn: .never) == nil)   // 보존 신호

        let biweekly = try #require(EventEditDraft.Recurrence.biweekly.rule(endingOn: .never))
        #expect(biweekly.frequency == .weekly)
        #expect(biweekly.interval == 2)

        let yearly = try #require(EventEditDraft.Recurrence.yearly.rule(endingOn: .never))
        #expect(yearly.frequency == .yearly)
        #expect(yearly.interval == 1)
    }

    /// 사용자 설정 규칙 왕복 — 매주(요일 지정)·매월(일자)·매년(월) 편집 지원.
    @Test func customRuleRoundTripsThroughEventKit() {
        let weekly = EventEditDraft.Recurrence.custom(
            .init(frequency: .weekly, interval: 2, weekdays: [2, 4])   // 월·수
        )
        let weeklyRule = weekly.rule(endingOn: .never)!
        #expect(EventEditDraft.Recurrence(rules: [weeklyRule]) == weekly)

        let monthly = EventEditDraft.Recurrence.custom(
            .init(frequency: .monthly, interval: 1, monthDays: [1, 15])
        )
        let monthlyRule = monthly.rule(endingOn: .never)!
        #expect(EventEditDraft.Recurrence(rules: [monthlyRule]) == monthly)

        let yearly = EventEditDraft.Recurrence.custom(
            .init(frequency: .yearly, interval: 1, months: [3, 9])
        )
        let yearlyRule = yearly.rule(endingOn: .never)!
        #expect(EventEditDraft.Recurrence(rules: [yearlyRule]) == yearly)
    }

    /// 반복 종료 날짜는 읽고 · 저장 시 그대로 되싣는다 — 프리셋 재구성 때 유실 금지.
    @Test func recurrenceEndDateSurvivesReadAndApply() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        let until = date(2026, 12, 31)
        event.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1, end: EKRecurrenceEnd(end: until)
        ))

        var draft = EventEditDraft(event: event)
        #expect(draft.recurrence == .weekly)
        #expect(draft.recurrenceEnd == .onDate(until))

        draft.title = "제목만 변경"
        draft.apply(to: event)

        #expect(event.recurrenceRules?.first?.frequency == .weekly)
        #expect(event.recurrenceRules?.first?.recurrenceEnd?.endDate == until)
    }

    /// 서수 요일 지정(매월 첫째 월요일 · 매년 3월 마지막 금요일) 왕복 — Apple "다음 순서로".
    @Test func ordinalWeekdayRuleRoundTrips() {
        let firstMonday = EventEditDraft.Recurrence.custom(
            .init(frequency: .monthly, interval: 1,
                  ordinal: 1, ordinalWeekday: EKWeekday.monday.rawValue)
        )
        let monthlyRule = firstMonday.rule(endingOn: .never)!
        #expect(monthlyRule.daysOfTheWeek?.map(\.dayOfTheWeek) == [.monday])
        #expect(monthlyRule.setPositions == [1])
        #expect(EventEditDraft.Recurrence(rules: [monthlyRule]) == firstMonday)

        let lastFridayOfMarch = EventEditDraft.Recurrence.custom(
            .init(frequency: .yearly, interval: 1, months: [3],
                  ordinal: -1, ordinalWeekday: EKWeekday.friday.rawValue)
        )
        let yearlyRule = lastFridayOfMarch.rule(endingOn: .never)!
        #expect(EventEditDraft.Recurrence(rules: [yearlyRule]) == lastFridayOfMarch)
    }

    /// weekNumber 방식으로 인코딩된 기존 규칙(월간 둘째 화요일)도 서수 편집으로 읽힌다.
    @Test func weekNumberEncodedOrdinalRuleIsReadable() {
        let rule = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.tuesday, weekNumber: 2)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil
        )

        #expect(EventEditDraft.Recurrence(rules: [rule])
                == .custom(.init(frequency: .monthly, interval: 1,
                                 ordinal: 2, ordinalWeekday: EKWeekday.tuesday.rawValue)))
    }

    /// 우리 편집기로 표현 불가한 규칙(횟수 종료·setPositions 등)은 foreign — 저장 시 보존.
    @Test func unrepresentableRulesAreForeignAndPreserved() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 5)
        ))
        var draft = EventEditDraft(event: event)
        #expect(draft.recurrence == .foreign)

        draft.title = "바뀐 제목"
        draft.apply(to: event)

        #expect(event.recurrenceRules?.first?.recurrenceEnd?.occurrenceCount == 5)   // 보존
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
        #expect(draft.location == EventEditDraft.Location(title: "3층"))
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
        draft.location = nil
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

    /// 요일 지정 매주 규칙은 편집 가능한 custom으로 읽히고, 그대로 저장해도 내용이 유지된다.
    /// 프리셋 밖 알림(-7분)은 custom 표시 + 저장 시 보존.
    @Test func weekdaySpecificRuleIsEditableCustomAndSurvivesApply() {
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
        #expect(draft.recurrence == .custom(.init(frequency: .weekly, interval: 3, weekdays: [EKWeekday.monday.rawValue])))
        #expect(draft.alarm == .custom)

        draft.title = "바뀐 제목"
        draft.apply(to: event)

        #expect(event.recurrenceRules?.first?.interval == 3)                              // 유지
        #expect(event.recurrenceRules?.first?.daysOfTheWeek?.map(\.dayOfTheWeek) == [.monday])
        #expect(event.alarms?.map(\.relativeOffset) == [-420])                            // 보존
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

    /// 지도에서 고른 위치(제목+주소+좌표)는 구조화 위치로 저장되고 다시 읽힌다.
    @Test func structuredLocationRoundTripsThroughEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 0))
        draft.title = "회의"
        draft.location = EventEditDraft.Location(
            title: "개봉역", address: "대한민국 서울특별시 구로구 경인로40길 47",
            latitude: 37.4944, longitude: 126.8586
        )

        draft.apply(to: event)

        // location 문자열은 "제목\n주소", 구조화 위치엔 좌표가 실린다.
        #expect(event.location == "개봉역\n대한민국 서울특별시 구로구 경인로40길 47")
        #expect(event.structuredLocation?.geoLocation?.coordinate.latitude == 37.4944)

        let reread = EventEditDraft(event: event)
        #expect(reread.location == draft.location)
    }

    /// 위치 제거 시 문자열·구조화 위치 모두 지운다.
    @Test func clearingLocationRemovesBothRepresentations() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.location = "어딘가"
        var draft = EventEditDraft(event: event)
        draft.title = "제목"

        draft.location = nil
        draft.apply(to: event)

        #expect(event.location == nil)
        #expect(event.structuredLocation == nil)
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
