//
//  CalendarWidgetKindTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 홈 화면 캘린더 위젯의 `kind` 문자열 목록.
///
/// LA에서 할 일을 체크하면 캘린더 위젯만 골라 갱신해야 하므로(전체 reload는 LA까지
/// 재생성해 위젯 예산을 태운다) "캘린더 위젯 전체"를 한 곳에서 알아야 한다. 이동형 3종은
/// `WidgetRangeKind`가 알지만 고정형은 대응 case가 없어 이 목록이 유일한 단일 출처다.
struct CalendarWidgetKindTests {

    /// 등록된 캘린더 위젯 8종이 빠짐없이 들어 있어야 한다 — 하나라도 빠지면 그 위젯만
    /// 조용히 낡은 그림을 들고 있게 되고, 목록을 보는 쪽에서는 알 방법이 없다.
    @Test func coversEveryCalendarWidget() {
        #expect(CalendarWidgetKind.all.count == 8)
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.monthFixed"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.month"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.threeDay"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.oneDay"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.eventList"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.reminderList"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.smallMonth"))
        #expect(CalendarWidgetKind.all.contains("azhy.cue.widget.today"))
    }

    /// 이동형 3종은 `WidgetRangeKind.widgetKind`와 **같은 문자열**이어야 한다.
    /// 갈라지면 셰브런은 A를, LA 체크 갱신은 B를 갱신하게 된다.
    @Test func matchesShiftableWidgetKinds() {
        for kind in WidgetRangeKind.allCases {
            #expect(CalendarWidgetKind.all.contains(kind.widgetKind))
        }
    }

    /// 고정형은 이동형이 아니다 — `WidgetRangeKind`로 표현되지 않는 위젯이 목록에
    /// 포함된다는 사실 자체가 이 타입이 존재하는 이유다.
    @Test func includesWidgetsWithoutRangeKind() {
        let shiftable = Set(WidgetRangeKind.allCases.map(\.widgetKind))
        let fixedOnly = Set(CalendarWidgetKind.all.filter { !shiftable.contains($0) })

        #expect(fixedOnly == [
            "azhy.cue.widget.monthFixed",
            "azhy.cue.widget.eventList",
            "azhy.cue.widget.reminderList",
            "azhy.cue.widget.smallMonth",
            "azhy.cue.widget.today",
        ])
    }

    /// 중복이 없어야 한다 — 같은 kind로 두 번 reload를 걸면 예산만 태운다.
    @Test func hasNoDuplicates() {
        #expect(Set(CalendarWidgetKind.all).count == CalendarWidgetKind.all.count)
    }
}
