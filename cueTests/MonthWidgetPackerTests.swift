//
//  MonthWidgetPackerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 데이터 소스가 날짜별 목록을 만들 때 쓰는 정렬 규칙.
/// 칸 배치는 `MonthWeekPacker`(주 단위)가 맡으므로 여기서는 순서만 본다.
struct MonthWidgetPackerTests {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 27, hour: hour, minute: minute))!
    }

    private func item(
        _ id: String,
        kind: WidgetCalendarItem.Kind,
        hour: Int = 0,
        minute: Int = 0
    ) -> WidgetCalendarItem {
        WidgetCalendarItem(
            id: id,
            title: id,
            start: at(hour, minute),
            end: at(hour, minute).addingTimeInterval(3600),
            kind: kind,
            colorHex: nil,
            isHighPriority: false
        )
    }

    // MARK: - 표시 순서

    @Test func sortsAllDayThenTimedThenReminders() {
        // 레퍼런스의 셀 순서 — 종일 캡슐이 맨 위, 그 아래 시간 일정, 미리알림이 맨 아래.
        let unsorted = [
            item("reminder", kind: .reminder, hour: 6),
            item("timed", kind: .timedEvent, hour: 9),
            item("allDay", kind: .allDayEvent, hour: 12)
        ]
        let sorted = MonthWidgetPacker.sorted(unsorted)

        #expect(sorted.map(\.id) == ["allDay", "timed", "reminder"])
    }

    @Test func sortsBySameKindByStartThenTitle() {
        let unsorted = [
            item("late", kind: .timedEvent, hour: 18),
            item("early", kind: .timedEvent, hour: 8),
            item("mid", kind: .timedEvent, hour: 12)
        ]
        #expect(MonthWidgetPacker.sorted(unsorted).map(\.id) == ["early", "mid", "late"])
    }

    @Test func sortIsStableForIdenticalStartsUsingTitle() {
        // 같은 시각 항목의 순서가 렌더마다 흔들리면 위젯이 깜빡인다 — 제목으로 결정론 확보.
        let sameTime = [
            item("zulu", kind: .timedEvent, hour: 9),
            item("alpha", kind: .timedEvent, hour: 9)
        ]
        #expect(MonthWidgetPacker.sorted(sameTime).map(\.id) == ["alpha", "zulu"])
    }
}
