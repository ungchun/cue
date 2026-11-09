//
//  RecurrenceNextOccurrenceTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// "이 미리 알림만 삭제"가 마감을 옮기는 곳 — 미리 알림 앱 실측(2026-11-09, iOS 26.2)이 기준.
/// 마감과 지금보다 모두 뒤인 첫 회차, 시각은 유지, 반복 종료일은 그날까지 포함, 없으면 nil(마지막 회차).
struct RecurrenceNextOccurrenceTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 0, _ mi: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    private func next(_ rule: RecurrenceRule, due: Date, now: Date) -> Date? {
        rule.nextOccurrence(after: due, now: now, calendar: calendar)
    }

    // MARK: - 지금 기준 (미리 알림 앱 실측 3·4·4b·7)

    @Test func allDayDueTodayMovesToTomorrow() {
        #expect(next(RecurrenceRule(frequency: .daily), due: date(2026, 11, 9), now: date(2026, 11, 9, 12, 7))
            == date(2026, 11, 10))
    }

    /// 11/6 매일(종일), 오늘 11/9 → 11/7도 오늘도 아닌 내일.
    @Test func overdueAllDaySkipsPastAndToday() {
        #expect(next(RecurrenceRule(frequency: .daily), due: date(2026, 11, 6), now: date(2026, 11, 9, 12, 7))
            == date(2026, 11, 10))
    }

    /// 11/6 오후 3시 매일, 지금 11/9 12:07 → 오늘 오후 3시가 아직 남았다.
    @Test func overdueTimedLandsLaterToday() {
        #expect(next(RecurrenceRule(frequency: .daily), due: date(2026, 11, 6, 15), now: date(2026, 11, 9, 12, 7))
            == date(2026, 11, 9, 15))
    }

    @Test func timedDueKeepsTimeOfDay() {
        #expect(next(RecurrenceRule(frequency: .daily), due: date(2026, 11, 9, 15), now: date(2026, 11, 9, 12))
            == date(2026, 11, 10, 15))
    }

    @Test func futureDueAdvancesByInterval() {
        #expect(next(RecurrenceRule(frequency: .daily, interval: 2), due: date(2026, 11, 20), now: date(2026, 11, 9))
            == date(2026, 11, 22))
    }

    // MARK: - 반복 종료 (실측 6·6b)

    /// 종료일은 저장된 시각과 무관하게 그날 하루를 포함한다.
    @Test func endDateIncludesItsWholeDay() {
        let rule = RecurrenceRule(frequency: .daily, endDate: date(2026, 11, 10, 12, 10))
        #expect(next(rule, due: date(2026, 11, 9), now: date(2026, 11, 9, 12)) == date(2026, 11, 10))
        #expect(next(rule, due: date(2026, 11, 9, 15), now: date(2026, 11, 9, 12)) == date(2026, 11, 10, 15))
    }

    @Test func endDateOnDueDayMeansLastOccurrence() {
        let rule = RecurrenceRule(frequency: .daily, endDate: date(2026, 11, 9, 12, 10))
        #expect(next(rule, due: date(2026, 11, 9), now: date(2026, 11, 9, 12)) == nil)
    }

    // MARK: - 사용자화 규칙

    @Test func weeklyOnWeekdays() {
        let rule = RecurrenceRule(frequency: .weekly, weekdays: [2, 4])   // 월·수
        #expect(next(rule, due: date(2026, 11, 9), now: date(2026, 11, 9)) == date(2026, 11, 11))
    }

    /// 격주 월·수 — 수요일 다음 주는 건너뛰고 그다음 주 월요일.
    @Test func everyOtherWeekSkipsOffWeek() {
        let rule = RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4])
        #expect(next(rule, due: date(2026, 11, 11), now: date(2026, 11, 9)) == date(2026, 11, 23))
    }

    @Test func weeklyWithoutWeekdaysFollowsDueWeekday() {
        #expect(next(RecurrenceRule(frequency: .weekly), due: date(2026, 11, 9), now: date(2026, 11, 9))
            == date(2026, 11, 16))
    }

    @Test func monthlyLastFriday() {
        let rule = RecurrenceRule(frequency: .monthly, ordinal: -1, ordinalWeekday: 6)
        #expect(next(rule, due: date(2026, 11, 27), now: date(2026, 11, 9)) == date(2026, 12, 25))
    }

    @Test func monthlySecondTuesday() {
        let rule = RecurrenceRule(frequency: .monthly, ordinal: 2, ordinalWeekday: 3)
        #expect(next(rule, due: date(2026, 11, 10), now: date(2026, 11, 9)) == date(2026, 12, 8))
    }

    /// 31일 매월 — 30일까지인 달은 건너뛴다(RFC 5545, EventKit과 같다).
    @Test func monthlyOn31stSkipsShortMonths() {
        #expect(next(RecurrenceRule(frequency: .monthly), due: date(2026, 10, 31), now: date(2026, 10, 1))
            == date(2026, 12, 31))
    }

    @Test func monthlyOnMonthDays() {
        let rule = RecurrenceRule(frequency: .monthly, monthDays: [1, 15])
        #expect(next(rule, due: date(2026, 11, 1), now: date(2026, 10, 1)) == date(2026, 11, 15))
    }

    @Test func yearlyInListedMonths() {
        let rule = RecurrenceRule(frequency: .yearly, months: [3, 9])
        #expect(next(rule, due: date(2026, 3, 15), now: date(2026, 1, 1)) == date(2026, 9, 15))
        #expect(next(RecurrenceRule(frequency: .yearly), due: date(2026, 3, 15), now: date(2026, 1, 1))
            == date(2027, 3, 15))
    }

    // MARK: - Reminder 관문 (선택 창을 띄울지)

    @Test func reminderWithoutRecurrenceOrCompletedHasNoNextOccurrence() {
        var reminder = Reminder(id: "1", title: "t", isCompleted: false, notes: nil,
                                dueDate: date(2026, 11, 9), listID: "A")
        #expect(reminder.nextOccurrence(now: date(2026, 11, 9), calendar: calendar) == nil)

        reminder.recurrence = RecurrenceRule(frequency: .daily)
        #expect(reminder.nextOccurrence(now: date(2026, 11, 9), calendar: calendar) == date(2026, 11, 10))

        reminder.isCompleted = true
        #expect(reminder.nextOccurrence(now: date(2026, 11, 9), calendar: calendar) == nil)
    }
}
