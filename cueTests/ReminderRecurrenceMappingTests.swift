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

    // MARK: - 편집 저장 시 보존 정책 (알람·반복 — 미리알림 앱과의 계약)

    /// cue가 관리하는 알람은 "마감 시각 절대 알람"뿐 — 위치·상대·기타 알람은 사용자가
    /// 미리알림 앱에서 단 것일 수 있어 편집 저장 시 보존해야 한다(일정 .custom 보존과 동일 계약).
    @Test func onlyPlainAbsoluteAlarmIsCueManaged() {
        let absolute = EKAlarm(absoluteDate: date(2026, 8, 1))
        #expect(ReminderMapper.isCueManagedDueAlarm(absolute))

        let relative = EKAlarm(relativeOffset: -300)
        #expect(!ReminderMapper.isCueManagedDueAlarm(relative))

        let location = EKAlarm(relativeOffset: 0)
        location.structuredLocation = EKStructuredLocation(title: "집")
        location.proximity = .enter
        #expect(!ReminderMapper.isCueManagedDueAlarm(location))

        // 절대시각이라도 위치가 붙어 있으면 위치 알람 — 보존.
        let absoluteWithLocation = EKAlarm(absoluteDate: date(2026, 8, 1))
        absoluteWithLocation.structuredLocation = EKStructuredLocation(title: "회사")
        #expect(!ReminderMapper.isCueManagedDueAlarm(absoluteWithLocation))
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
