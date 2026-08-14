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
}
