//
//  WidgetCalendarItemTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 위젯 목록의 시각 줄 분기 근거 — "날짜만 지정한" 항목인지.
///
/// 마감에 시각이 없는 할일은 EventKit이 자정으로 돌려줘, 시각 분기로 빠지면 "0:00"이
/// 찍힌다(실기기 확인). 뷰는 이 판정 하나로 종일 표기(날짜+요일)와 시각 표기를 가른다.
struct WidgetCalendarItemTests {

    private func item(kind: WidgetCalendarItem.Kind, hasTime: Bool = true) -> WidgetCalendarItem {
        let date = Date(timeIntervalSince1970: 1_784_000_000)
        return WidgetCalendarItem(
            id: "x", title: "제목", start: date, end: date,
            kind: kind, colorHex: nil, isHighPriority: false, hasTime: hasTime
        )
    }

    @Test func allDayEventDisplaysAsDateOnly() {
        #expect(item(kind: .allDayEvent).displaysAsDateOnly)
    }

    @Test func timedEventDisplaysItsTime() {
        #expect(!item(kind: .timedEvent).displaysAsDateOnly)
    }

    @Test func dateOnlyReminderDisplaysAsDateOnly() {
        // 마감 "날짜만" 지정한 할일 — 자정 시각(0:00)을 보여주면 안 된다.
        #expect(item(kind: .reminder, hasTime: false).displaysAsDateOnly)
    }

    @Test func timedReminderDisplaysItsTime() {
        // "오후 3시까지"처럼 시각을 지정한 할일은 그 시각이 정보다.
        #expect(!item(kind: .reminder, hasTime: true).displaysAsDateOnly)
    }

    // MARK: - 완료 버튼 노출(supportsCompletion)
    //
    // 위젯 목록의 마커를 완료 버튼으로 감쌀지 — 인텐트가 받을 EventKit 식별자
    // (`reminderID`)가 있어야 한다. 표시용 `id`는 반복 회차 구분용 합성값이라 못 쓴다.

    private func reminderItem(
        reminderID: String? = "ek-1",
        isCompleted: Bool = false,
        kind: WidgetCalendarItem.Kind = .reminder
    ) -> WidgetCalendarItem {
        let date = Date(timeIntervalSince1970: 1_784_000_000)
        return WidgetCalendarItem(
            id: "x", title: "제목", start: date, end: date,
            kind: kind, colorHex: nil, isHighPriority: false,
            reminderID: reminderID, isCompleted: isCompleted
        )
    }

    @Test func incompleteReminderWithIDSupportsCompletion() {
        #expect(reminderItem().supportsCompletion)
    }

    @Test func completedReminderDoesNotSupportCompletion() {
        // 이미 완료된 항목에 또 완료 인텐트를 쏠 이유가 없다.
        #expect(!reminderItem(isCompleted: true).supportsCompletion)
    }

    @Test func reminderWithoutIDDoesNotSupportCompletion() {
        // 표본(갤러리 미리보기) 항목은 EventKit 식별자가 없다 — 버튼이면 안 된다.
        #expect(!reminderItem(reminderID: nil).supportsCompletion)
    }

    @Test func eventsNeverSupportCompletion() {
        // 일정에는 완료 개념이 없다.
        #expect(!reminderItem(kind: .timedEvent).supportsCompletion)
        #expect(!reminderItem(kind: .allDayEvent).supportsCompletion)
    }
}
