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

    /// 표현 못 하는 규칙(횟수 종료 등)은 빈도·간격만으로 단순화 — nil로 잃지 않는다. 단순화했다는 표시를 남긴다.
    @Test func unsupportedDetailsFallBackToFrequencyAndInterval() {
        let ek = EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 3, end: EKRecurrenceEnd(occurrenceCount: 5)
        )
        #expect(ReminderMapper.toRecurrence(ek) == RecurrenceRule(frequency: .weekly, interval: 3, isApproximate: true))
    }

    /// 미리 알림 앱의 "마지막 평일"(요일 여럿 + 위치) — 모양은 못 담아 단순화하되 종료일은 지키고,
    /// 단순화 표시를 남겨 "이 미리 알림만 삭제"가 엉뚱한 날(다음 달 같은 일자)로 옮기지 않게 한다.
    @Test func lastWeekdayRuleKeepsEndDateAndIsMarkedApproximate() {
        let until = date(2026, 12, 31)
        let weekdays: [EKWeekday] = [.monday, .tuesday, .wednesday, .thursday, .friday]
        let ek = EKRecurrenceRule(
            recurrenceWith: .monthly, interval: 1,
            daysOfTheWeek: weekdays.map { EKRecurrenceDayOfWeek($0) },
            daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil,
            daysOfTheYear: nil, setPositions: [-1], end: EKRecurrenceEnd(end: until)
        )
        #expect(ReminderMapper.toRecurrence(ek)
                == RecurrenceRule(frequency: .monthly, endDate: until, isApproximate: true))
    }

    // MARK: - "이 미리 알림만 삭제" — EKReminder 마감 옮기기

    /// 마감은 **자기 시간대**로 센다 — 기기 시간대와 달라도(예: 서울 기기에서 호놀룰루 마감 11/10 22:00)
    /// 다음 날 같은 시각으로 간다. 기기 달력으로 세면 날짜가 하루 더 밀리거나 안 밀린다.
    /// 알람도 새 마감과 같은 순간으로 따라가야 다음 편집에서 cue 마감 알람으로 인식된다.
    @Test func movingDueCountsInItsOwnTimeZone() throws {
        let honolulu = try #require(TimeZone(identifier: "Pacific/Honolulu"))
        var local = Calendar(identifier: .gregorian)
        local.timeZone = honolulu
        let oldDue = try #require(local.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 22)))
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.dueDateComponents = DateComponents(
            calendar: Calendar(identifier: .gregorian), timeZone: honolulu,
            year: 2026, month: 11, day: 10, hour: 22, minute: 0
        )
        reminder.addAlarm(EKAlarm(absoluteDate: oldDue))

        let moved = ReminderMapper.moveDueToNextOccurrence(
            of: reminder, rule: RecurrenceRule(frequency: .daily), now: oldDue.addingTimeInterval(3600)
        )

        #expect(moved)
        let components = try #require(reminder.dueDateComponents)
        #expect([components.year, components.month, components.day, components.hour] == [2026, 11, 11, 22])
        #expect(reminder.alarms?.first?.absoluteDate == oldDue.addingTimeInterval(86_400))
    }

    /// 종일 마감은 종일로 남는다(시각 필드가 생기지 않는다). 마지막 회차면 손대지 않고 false.
    @Test func movingAllDayDueStaysAllDayAndStopsAtLastOccurrence() throws {
        let reminder = EKReminder(eventStore: EKEventStore())
        reminder.dueDateComponents = DateComponents(year: 2026, month: 11, day: 10)
        let now = try #require(DateComponents(calendar: .current, year: 2026, month: 11, day: 10, hour: 12).date)

        #expect(ReminderMapper.moveDueToNextOccurrence(of: reminder, rule: RecurrenceRule(frequency: .daily), now: now))
        #expect(reminder.dueDateComponents?.day == 11)
        #expect(reminder.dueDateComponents?.hour == nil)

        let endsOn11th = RecurrenceRule(frequency: .daily, endDate: now.addingTimeInterval(86_400))
        #expect(!ReminderMapper.moveDueToNextOccurrence(of: reminder, rule: endsOn11th, now: now))
        #expect(reminder.dueDateComponents?.day == 11)
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

        // 반복 종료는 endDate로 합쳐진다 — 고른 날의 끝으로.
        let until = date(2026, 12, 31)
        let ended = EventEditDraft.Recurrence.monthly.reminderRule(endingOn: .onDate(until))
        #expect(ended == RecurrenceRule(frequency: .monthly, endDate: EventEditDraft.RecurrenceEnd.endOfDay(until)))

        // 안 함은 nil.
        #expect(EventEditDraft.Recurrence.none.reminderRule(endingOn: .never) == nil)
    }

    /// 피커가 단 시각(마감 시각)과 무관하게 종료일 당일 끝까지 반복한다 — 마감을 늦춰도
    /// 종료일 회차가 빠지지 않는다. 이미 날 끝이면 그대로(편집 왕복에서 값이 흔들리지 않음).
    @Test func reminderEndDateCoversWholeEndDay() throws {
        let calendar = Calendar.current
        let picked = try #require(DateComponents(calendar: calendar, year: 2026, month: 11, day: 26, hour: 9, minute: 50).date)
        let rule = try #require(EventEditDraft.Recurrence.daily.reminderRule(endingOn: .onDate(picked)))
        let end = try #require(rule.endDate)

        #expect(calendar.isDate(end, inSameDayAs: picked))
        #expect(calendar.dateComponents([.hour, .minute, .second], from: end) == DateComponents(hour: 23, minute: 59, second: 59))
        let again = EventEditDraft.Recurrence.daily.reminderRule(endingOn: .onDate(end))
        #expect(again?.endDate == end)
    }

    /// endDate 있는 도메인 규칙 → UI로 갈 때 RecurrenceEnd가 분리된다.
    @Test func endDateSplitsIntoRecurrenceEnd() {
        let until = date(2026, 12, 31)
        let rule = RecurrenceRule(frequency: .weekly, endDate: until)
        #expect(EventEditDraft.RecurrenceEnd(reminderRule: rule) == .onDate(until))
        #expect(EventEditDraft.RecurrenceEnd(reminderRule: nil) == .never)
    }

    // MARK: - 편집 저장 시 보존 정책 (알람·반복 — 미리알림 앱과의 계약)

    /// cue가 관리하는 알람은 "이전 마감 시각의 절대 알람"뿐 — 다른 시각의 절대 알람·위치·상대
    /// 알람은 사용자가 미리알림 앱에서 단 것일 수 있어 편집 저장 시 보존해야 한다(일정 .custom 보존과 동일 계약).
    @Test func onlyAbsoluteAlarmAtPreviousDueIsCueManaged() {
        let due = date(2026, 8, 1).addingTimeInterval(9 * 3600)   // 09:00
        // 저장 당시 초가 붙어 있어도 같은 분이면 cue가 단 마감 알람.
        #expect(ReminderMapper.isCueManagedDueAlarm(EKAlarm(absoluteDate: due.addingTimeInterval(23)), previousDue: due))

        // 다른 시각의 절대 알람(사용자가 단 추가 알람) — 보존.
        let other = EKAlarm(absoluteDate: due.addingTimeInterval(-3600))
        #expect(!ReminderMapper.isCueManagedDueAlarm(other, previousDue: due))
        // 이전 마감이 없거나 종일이면 cue가 단 알람이 없다 — 어떤 절대 알람도 보존.
        #expect(!ReminderMapper.isCueManagedDueAlarm(EKAlarm(absoluteDate: due), previousDue: nil))

        let relative = EKAlarm(relativeOffset: -300)
        #expect(!ReminderMapper.isCueManagedDueAlarm(relative, previousDue: due))

        // 절대시각이라도 위치가 붙어 있으면 위치 알람 — 보존.
        let absoluteWithLocation = EKAlarm(absoluteDate: due)
        absoluteWithLocation.structuredLocation = EKStructuredLocation(title: "회사")
        #expect(!ReminderMapper.isCueManagedDueAlarm(absoluteWithLocation, previousDue: due))
    }

    /// 반복 재기록은 실제로 바뀌었을 때만 — 도메인이 표현 못 하는 원본 세부(횟수 종료 등)를
    /// 가진 규칙도, 편집에서 반복을 안 건드렸으면 동치로 판정돼 그대로 보존된다.
    @Test func recurrenceRewriteSkippedWhenEquivalent() {
        // 횟수 종료(COUNT 5) — 도메인은 빈도·간격만으로 단순화해 읽는다.
        let countRule = EKRecurrenceRule(
            recurrenceWith: .weekly, interval: 1,
            end: EKRecurrenceEnd(occurrenceCount: 5)
        )
        let simplified = ReminderMapper.toRecurrence(countRule)

        // 시트가 안 건드리고 되돌려준 단순화 규칙 = 동치 → 재기록 없음(COUNT 보존).
        #expect(ReminderMapper.isEquivalentRecurrence(countRule, to: simplified))
        // 실제 변경(빈도 다름) → 재기록.
        #expect(!ReminderMapper.isEquivalentRecurrence(
            countRule, to: RecurrenceRule(frequency: .daily, interval: 1)
        ))
        // 반복 제거 → 재기록(삭제).
        #expect(!ReminderMapper.isEquivalentRecurrence(countRule, to: nil))
        // 반복 없음 ↔ 없음 = 동치, 없음 ↔ 추가 = 재기록.
        #expect(ReminderMapper.isEquivalentRecurrence(nil, to: nil))
        #expect(!ReminderMapper.isEquivalentRecurrence(nil, to: simplified))
    }

    /// 도메인이 온전히 표현하는 리치 규칙(요일 집합·종료일)도 동치 판정이 정확해야 —
    /// 안 바꾸면 재기록 생략, 종료일만 바꿔도 재기록.
    @Test func equivalenceCoversRichRulesAndEndDateChanges() {
        let until = date(2026, 12, 31)
        let ekRule = ReminderMapper.toEKRecurrenceRule(
            RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4], endDate: until)
        )
        let readBack = ReminderMapper.toRecurrence(ekRule)

        // 왕복 값 그대로 = 동치(재기록 생략).
        #expect(ReminderMapper.isEquivalentRecurrence(ekRule, to: readBack))
        // 종료일 제거·요일 변경은 재기록 대상.
        #expect(!ReminderMapper.isEquivalentRecurrence(
            ekRule, to: RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 4])
        ))
        #expect(!ReminderMapper.isEquivalentRecurrence(
            ekRule, to: RecurrenceRule(frequency: .weekly, interval: 2, weekdays: [2, 6], endDate: until)
        ))
        // 반복 제거 매핑(nil → EK 규칙 없음) — 저장 경로의 전제.
        #expect(ReminderMapper.toEKRecurrenceRule(nil) == nil)
    }
}
