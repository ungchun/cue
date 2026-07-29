//
//  WidgetCalendarItem.swift
//  cue / Shared
//

import Foundation

/// 홈 화면 위젯이 그리는 항목 한 건 — 캘린더 일정과 미리알림을 하나의 표시용 타입으로 합친다.
///
/// 위젯 익스텐션은 Domain(`CalendarEvent`·`Reminder`)을 모르므로, EventKit에서 읽어온
/// 값을 이 DTO로 눕혀서 뷰까지 흘린다. `colorHex`는 EventKit이 주는 캘린더/미리알림 리스트
/// 색을 그대로 담는다 — 디자인 시스템 색 규칙의 **외부 데이터 표현 예외**다.
///
/// 앱·익스텐션 양쪽 타깃에 컴파일된다(`Foundation`만 의존).
struct WidgetCalendarItem: Identifiable, Hashable, Sendable {

    /// 그리는 방식을 가르는 종류 — 이 값이 칩 모양(채움/옅음/원형 마커)을 결정한다.
    enum Kind: Int, Hashable, Sendable, Comparable {
        /// 종일 일정 — 캘린더 색으로 **꽉 채운** 칩.
        case allDayEvent = 0
        /// 시각이 지정된 일정 — 옅은 배경 + 제목 앞 작은 색 사각.
        case timedEvent = 1
        /// 미리알림 — 배경 없이 제목 앞 원형 마커.
        case reminder = 2

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let title: String
    let start: Date
    /// 미리알림은 길이가 없어 `start == end`. 타임라인은 `DayTimelineLayout`이 최소 길이를 준다.
    let end: Date
    let kind: Kind
    /// 캘린더(일정) 또는 미리알림 리스트(할일)의 색 `"#RRGGBB"`. `nil`이면 뷰가 시스템 accent로 폴백.
    let colorHex: String?
    /// 미리알림의 우선순위 지정 여부 — 원형 마커를 채울지(지정) 비울지(미지정) 가른다.
    /// 일정에는 의미가 없어 항상 `false`.
    let isHighPriority: Bool

    /// 완료된 미리알림인지. 일정에는 의미가 없어 항상 `false`.
    ///
    /// 완료해도 **오늘 이후 마감이면 계속 보여준다** — 오늘 할 일을 끝냈다는 사실 자체가
    /// 정보다. 지나간 것만 숨겨 위젯이 과거로 채워지는 걸 막는다(→ `WidgetCalendarDataSource`).
    var isCompleted: Bool = false

    var isAllDay: Bool { kind == .allDayEvent }
}
