//
//  WidgetReminderVisibilityTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 완료된 할일을 위젯에 그릴지 가르는 규칙.
///
/// 미완료는 언제나 그린다. 완료된 것은 **오늘 이후 마감만** 남긴다 — 오늘 끝낸 일은 그날
/// 무엇을 했는지 알려주지만, 지난 것까지 두면 위젯이 이미 끝난 일로 채워진다.
struct WidgetReminderVisibilityTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// 오늘 자정 — 규칙의 경계값이다.
    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 29))!
    }

    private func at(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func shows(completed: Bool, due: Date) -> Bool {
        WidgetCalendarDataSource.showsReminder(isCompleted: completed, due: due, today: today)
    }

    // MARK: - 미완료

    @Test func incompleteRemindersAlwaysShow() {
        // 마감이 언제든 아직 할 일이면 보여준다 — 지난 것도 놓친 일로서 의미가 있다.
        #expect(shows(completed: false, due: at(20)))
        #expect(shows(completed: false, due: at(29)))
        #expect(shows(completed: false, due: at(31)))
    }

    // MARK: - 완료

    @Test func completedRemindersDueTodayStillShow() {
        // 오늘 끝낸 일은 남긴다 — 그날 무엇을 했는지가 정보다.
        #expect(shows(completed: true, due: at(29, 0)))
        #expect(shows(completed: true, due: at(29, 9)))
        #expect(shows(completed: true, due: at(29, 23)))
    }

    @Test func completedRemindersDueLaterStillShow() {
        // 미리 끝낸 일도 마감이 아직 안 지났으면 남긴다.
        #expect(shows(completed: true, due: at(30)))
        #expect(shows(completed: true, due: at(31)))
    }

    @Test func completedRemindersDueBeforeTodayAreHidden() {
        // 지나간 것만 숨긴다 — 안 그러면 위젯이 이미 끝난 일로 채워진다.
        #expect(!shows(completed: true, due: at(28)))
        #expect(!shows(completed: true, due: at(1)))
    }

    /// 경계는 **오늘 자정**이다 — 어제 23:59는 숨기고 오늘 00:00은 남긴다.
    ///
    /// 시각이 아니라 날짜로 가르는 게 핵심이다. "지금"을 기준으로 하면 오늘 오전에 끝낸
    /// 일이 오후에 사라져, 같은 날인데 위젯이 달라 보인다.
    @Test func theCutoffIsMidnightNotTheCurrentMoment() {
        let yesterdayLastMoment = today.addingTimeInterval(-1)
        #expect(!shows(completed: true, due: yesterdayLastMoment))
        #expect(shows(completed: true, due: today))
    }
}
