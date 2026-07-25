//
//  ReminderRecurrenceMappingTests.swift
//  cueTests
//

import EventKit
import Foundation
import Testing
@testable import cue

/// 할일 반복 파이프라인 계약 — 도메인 `RecurrenceRule` ↔ EventKit 규칙(ReminderMapper),
/// 그리고 도메인 ↔ 편집 UI 모델(EventEditDraft.Recurrence) 브리지.
struct ReminderRecurrenceMappingTests {

    private func date(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        DateComponents(calendar: .current, year: y, month: mo, day: d).date!
    }

    // MARK: - 도메인 → EKRecurrenceRule → 도메인 왕복 (ReminderMapper)

    @Test func presetRoundTripsThroughEventKit() throws {
        let daily = RecurrenceRule(frequency: .daily)
        let ek = try #require(ReminderMapper.toEKRecurrenceRule(daily))
        #expect(ek.frequency == .daily)
        #expect(ek.interval == 1)
        #expect(ReminderMapper.toRecurrence(ek) == daily)
    }

    @Test func weeklyWithWeekdaysRoundTrips() throws {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4])   // 월·수
        let ek = try #require(ReminderMapper.toEKRecurrenceRule(rule))
        #expect(ek.daysOfTheWeek?.map(\.dayOfTheWeek) == [.monday, .wednesday])
        #expect(ReminderMapper.toRecurrence(ek) == rule)
    }

    @Test func monthlyOrdinalWeekdayRoundTrips() throws {
        let rule = RecurrenceRule(frequency: .monthly, ordinal: -1, ordinalWeekday: 6)   // 마지막 금요일
        let ek = try #require(ReminderMapper.toEKRecurrenceRule(rule))
        #expect(ek.setPositions == [-1])
        #expect(ReminderMapper.toRecurrence(ek) == rule)
    }

    @Test func yearlyMonthsAndEndDateRoundTrip() throws {
        let until = date(2027, 1, 1)
        let rule = RecurrenceRule(frequency: .yearly, months: [3, 9], endDate: until)
        let ek = try #require(ReminderMapper.toEKRecurrenceRule(rule))
        #expect(ek.recurrenceEnd?.endDate == until)
        #expect(ReminderMapper.toRecurrence(ek) == rule)
    }

    /// weekNumber 인코딩("둘째 화요일")도 서수로 읽힌다 — 외부에서 만든 규칙 호환.
    @Test func weekNumberEncodedRuleReadsAsOrdinal() {
        let ek = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: [EKRecurrenceDayOfWeek(.tuesday, weekNumber: 2)],
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: nil, end: nil
        )
        #expect(ReminderMapper.toRecurrence(ek)
                == RecurrenceRule(frequency: .monthly, ordinal: 2, ordinalWeekday: 3))
    }

    /// 표현 못 하는 규칙(횟수 종료 등)은 빈도·간격만으로 단순화 — nil로 잃지 않는다.
    @Test func unsupportedDetailsFallBackToFrequencyAndInterval() {
        let ek = EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 3, end: EKRecurrenceEnd(occurrenceCount: 5)
        )
        #expect(ReminderMapper.toRecurrence(ek) == RecurrenceRule(frequency: .weekly, interval: 3))
    }

    // MARK: - 도메인 ↔ 편집 UI 모델 브리지

    @Test func domainRuleBridgesToUIRecurrenceAndBack() {
        // 프리셋 동치는 프리셋으로.
        #expect(EventEditDraft.Recurrence(reminderRule: nil) == EventEditDraft.Recurrence.none)
        #expect(EventEditDraft.Recurrence(reminderRule: RecurrenceRule(frequency: .daily)) == .daily)
        #expect(EventEditDraft.Recurrence(reminderRule: RecurrenceRule(frequency: .weekly, interval: 2)) == .biweekly)

        // 상세 지정은 custom 페이로드로 왕복.
        let rich = RecurrenceRule(frequency: .weekly, interval: 1, weekdays: [2, 4])
        let ui = EventEditDraft.Recurrence(reminderRule: rich)
        #expect(ui == .custom(.init(frequency: .weekly, interval: 1, weekdays: [2, 4])))
        #expect(ui.reminderRule(endingOn: .never) == rich)

        // 반복 종료는 endDate로 합쳐진다.
        let until = date(2026, 12, 31)
        let ended = EventEditDraft.Recurrence.monthly.reminderRule(endingOn: .onDate(until))
        #expect(ended == RecurrenceRule(frequency: .monthly, endDate: until))

        // 안 함은 nil.
        #expect(EventEditDraft.Recurrence.none.reminderRule(endingOn: .never) == nil)
    }

    /// endDate 있는 도메인 규칙 → UI로 갈 때 RecurrenceEnd가 분리된다.
    @Test func endDateSplitsIntoRecurrenceEnd() {
        let until = date(2026, 12, 31)
        let rule = RecurrenceRule(frequency: .weekly, endDate: until)
        #expect(EventEditDraft.RecurrenceEnd(reminderRule: rule) == .onDate(until))
        #expect(EventEditDraft.RecurrenceEnd(reminderRule: nil) == .never)
    }
}
