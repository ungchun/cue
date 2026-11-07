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

    /// 반복을 안 바꾼 저장은 규칙을 다시 달지 않는다 — 회차 하나를 "이 이벤트에만" 저장할 때
    /// 같은 규칙을 지웠다 다시 달면 원본 시리즈가 깨져 다른 회차가 사라졌다(QA 실측).
    @Test func unchangedRecurrenceKeepsOriginalRule() throws {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 11, 14, 16, 0)
        event.endDate = date(2026, 11, 14, 17, 0)
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil))
        let original = try #require(event.recurrenceRules?.first)

        var draft = EventEditDraft(event: event)
        draft.title = "회차만 제목 변경"
        draft.apply(to: event)
        #expect(event.recurrenceRules?.count == 1)
        #expect(event.recurrenceRules?.first === original)

        draft.recurrence = .daily
        draft.apply(to: event)
        #expect(event.recurrenceRules?.count == 1)
        #expect(event.recurrenceRules?.first?.frequency == .daily)
        #expect(event.recurrenceRules?.first !== original)
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
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1, end: EKRecurrenceEnd(occurrenceCount: 5)
        ))
        var draft = EventEditDraft(event: event)
        #expect(draft.recurrence == .foreign)

        draft.title = "바뀐 제목"
        draft.apply(to: event)

        #expect(event.recurrenceRules?.first?.recurrenceEnd?.occurrenceCount == 5)   // 보존
    }

    // MARK: - 알림 옵션 ↔ EKAlarm

    private func timedAlarm(_ offset: TimeInterval) -> EventEditDraft.Alarm {
        EventEditDraft.Alarm(alarm: EKAlarm(relativeOffset: offset), isAllDay: false)
    }

    private func allDayAlarm(_ offset: TimeInterval) -> EventEditDraft.Alarm {
        EventEditDraft.Alarm(alarm: EKAlarm(relativeOffset: offset), isAllDay: true)
    }

    @Test func alarmOptionMapsFromRelativeOffset() {
        #expect(timedAlarm(0) == .atTime)
        #expect(timedAlarm(-300) == .minutesBefore(5))
        #expect(timedAlarm(-3600) == .minutesBefore(60))
        #expect(timedAlarm(-86_400) == .minutesBefore(1_440))
        // 프리셋 밖 오프셋(-7분 등)은 custom — 저장 시 기존 알림을 보존한다.
        #expect(timedAlarm(-420) == .custom)
    }

    @Test func alarmOptionProducesRelativeOffset() {
        #expect(EventEditDraft.Alarm.none.relativeOffset == nil)
        #expect(EventEditDraft.Alarm.atTime.relativeOffset == 0)
        #expect(EventEditDraft.Alarm.minutesBefore(30).relativeOffset == -1800)
        #expect(EventEditDraft.Alarm.custom.relativeOffset == nil)
    }

    /// 종일 프리셋은 자정 기준 오프셋 — 당일 9시 = +9h, 1일 전 9시 = -15h, 2일 전 = -39h, 1주 전 = -159h.
    @Test func allDayPresetsMapBothWays() {
        let expected: [(Int, TimeInterval)] = [(0, 32_400), (1, -54_000), (2, -140_400), (7, -572_400)]
        for (days, offset) in expected {
            #expect(EventEditDraft.Alarm.daysBeforeAt9AM(days).relativeOffset == offset)
            #expect(allDayAlarm(offset) == .daysBeforeAt9AM(days))
        }
        // 시간 지정 프리셋 오프셋도 종일 이벤트에선 프리셋이 아니다 — 보존.
        #expect(allDayAlarm(-900) == .custom)
        // 반대로 종일 프리셋 오프셋은 시간 지정 이벤트에서 custom.
        #expect(timedAlarm(-54_000) == .custom)
    }

    /// 사용자 지정(절대 일시) 알림 왕복.
    @Test func absoluteAlarmRoundTrips() {
        let fireDate = date(2026, 7, 24, 20, 30)
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.addAlarm(EKAlarm(absoluteDate: fireDate))

        var draft = EventEditDraft(event: event)
        #expect(draft.firstAlarm == .absolute(fireDate))

        draft.firstAlarm = .absolute(date(2026, 7, 24, 21, 0))
        draft.apply(to: event)

        #expect(event.alarms?.count == 1)
        #expect(event.alarms?.first?.absoluteDate == date(2026, 7, 24, 21, 0))
    }

    /// 알림 두 칸 — 이벤트에 가까운 알림이 첫 칸(추가 순서와 무관). 첫 칸이 없음이면 두 번째도 쓰지 않는다.
    /// EventKit은 추가 순서를 보존하지 않으므로 저장 결과는 집합으로 비교한다.
    @Test func twoAlarmSlotsMapBothWays() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.addAlarm(EKAlarm(relativeOffset: -3600))
        event.addAlarm(EKAlarm(relativeOffset: -600))

        var draft = EventEditDraft(event: event)
        #expect(draft.firstAlarm == .minutesBefore(10))
        #expect(draft.secondAlarm == .minutesBefore(60))

        draft.secondAlarm = .minutesBefore(1_440)
        draft.apply(to: event)
        #expect(Set(event.alarms?.map(\.relativeOffset) ?? []) == [-600, -86_400])
        let reread = EventEditDraft(event: event)
        #expect(reread.firstAlarm == .minutesBefore(10))
        #expect(reread.secondAlarm == .minutesBefore(1_440))

        draft.firstAlarm = EventEditDraft.Alarm.none
        draft.apply(to: event)
        #expect(event.alarms == nil || event.alarms?.isEmpty == true)
    }

    /// 한 칸만 표현 불가(-7분)면 그 칸의 원본을 남기고 다른 칸만 바꾼다.
    @Test func customSlotKeepsOriginalAlarmWhileOtherSlotChanges() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.addAlarm(EKAlarm(relativeOffset: -420))
        var draft = EventEditDraft(event: event)
        #expect(draft.firstAlarm == .custom)

        draft.secondAlarm = .atTime
        draft.apply(to: event)

        #expect(Set(event.alarms?.map(\.relativeOffset) ?? []) == [-420, 0])
    }

    /// 알림 3개 이상은 두 칸으로 못 그린다 — 두 칸 모두 custom, 저장 시 전부 보존.
    @Test func threeOrMoreAlarmsArePreserved() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        [-300, -600, -900].forEach { event.addAlarm(EKAlarm(relativeOffset: TimeInterval($0))) }
        var draft = EventEditDraft(event: event)
        #expect(draft.firstAlarm == .custom)
        #expect(draft.secondAlarm == .custom)

        draft.title = "제목만 변경"
        draft.apply(to: event)

        #expect(event.alarms?.count == 3)
    }

    /// 종일 전환 시 새 체계에 없는 알림 프리셋은 없음으로 — 사용자 지정은 유지.
    @Test func togglingAllDayResetsIncompatibleAlarmPresets() {
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 0))
        draft.firstAlarm = .minutesBefore(15)
        draft.secondAlarm = .absolute(date(2026, 7, 25, 9, 0))

        draft.isAllDay = true

        #expect(draft.firstAlarm == EventEditDraft.Alarm.none)
        #expect(draft.secondAlarm == .absolute(date(2026, 7, 25, 9, 0)))
    }

    // MARK: - 시간대

    /// 시간대를 바꾸면 벽시계 시각은 유지 — 서울 10:00 → 뉴욕 10:00.
    @Test func changingTimeZoneKeepsWallClockTime() throws {
        let seoul = try #require(TimeZone(identifier: "Asia/Seoul"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        var seoulCalendar = Calendar(identifier: .gregorian)
        seoulCalendar.timeZone = seoul
        var newYorkCalendar = Calendar(identifier: .gregorian)
        newYorkCalendar.timeZone = newYork
        let tenSeoul = try #require(seoulCalendar.date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 10)))
        var draft = EventEditDraft.newEvent(now: tenSeoul, calendar: seoulCalendar)

        draft.setTimeZone(newYork, deviceZone: seoul)

        #expect(draft.timeZone == newYork)
        #expect(draft.start == newYorkCalendar.date(from: DateComponents(year: 2026, month: 7, day: 25, hour: 10)))
        #expect(draft.end.timeIntervalSince(draft.start) == 3600)
    }

    /// 시간대 읽기·쓰기.
    @Test func timeZoneMapsBothWays() throws {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.timeZone = TimeZone(identifier: "Europe/Paris")
        var draft = EventEditDraft(event: event)
        #expect(draft.timeZone == event.timeZone)

        let tokyo = try #require(TimeZone(identifier: "Asia/Tokyo"))
        draft.setTimeZone(tokyo)
        draft.apply(to: event)

        #expect(event.timeZone?.identifier == "Asia/Tokyo")
    }

    // MARK: - 다음으로 표시

    @Test func availabilityOptionsFollowCalendarSupport() {
        #expect(EventEditDraft.availabilityOptions(for: []).isEmpty)
        #expect(EventEditDraft.availabilityOptions(for: [.busy, .free]) == [.busy, .free])
        #expect(EventEditDraft.availabilityOptions(for: [.busy, .free, .tentative, .unavailable])
                == [.busy, .free, .tentative, .unavailable])
    }

    /// 읽은 값을 그대로 담고, `.notSupported`로 저장하면 이벤트 값을 건드리지 않는다.
    /// (캘린더 없는 테스트 이벤트에서 EventKit이 무엇을 돌려줄지에 기대지 않게 "전과 같음"으로 본다.)
    @Test func availabilityReadsAndNotSupportedLeavesEventUntouched() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        var draft = EventEditDraft(event: event)
        #expect(draft.availability == event.availability)

        let before = event.availability
        draft.availability = .notSupported
        draft.apply(to: event)

        #expect(event.availability == before)
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
        #expect(draft.firstAlarm == .minutesBefore(10))
        #expect(draft.secondAlarm == EventEditDraft.Alarm.none)
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
        draft.firstAlarm = .minutesBefore(15)
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
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
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
        #expect(draft.firstAlarm == .custom)

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
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 3, end: nil))
        event.addAlarm(EKAlarm(relativeOffset: -420))
        var draft = EventEditDraft(event: event)

        draft.recurrence = .monthly
        draft.firstAlarm = EventEditDraft.Alarm.none
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
        event.startDate = date(2026, 7, 25, 10, 0)
        event.endDate = date(2026, 7, 25, 11, 0)
        event.location = "어딘가"
        var draft = EventEditDraft(event: event)
        draft.title = "제목"

        draft.location = nil
        draft.apply(to: event)

        #expect(event.location == nil)
        #expect(event.structuredLocation == nil)
    }

    /// 종일 전환 시 날짜(달력일)는 유지된다 — EventKit이 종일 이벤트의 시각을
    /// 자정으로 정규화하므로 순간이 아니라 "같은 날"이 계약이다.
    @Test func applyKeepsDatesWhenTogglingAllDay() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        var draft = EventEditDraft.newEvent(now: date(2026, 7, 25, 14, 0))
        draft.isAllDay = true

        draft.apply(to: event)

        #expect(event.isAllDay)
        #expect(Calendar.current.isDate(event.startDate, inSameDayAs: draft.start))
    }
}
