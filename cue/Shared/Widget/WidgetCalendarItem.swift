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

    /// `start`에 의미 있는 시각이 있는지. 마감 "날짜만" 지정한 할일은 EventKit이 자정을
    /// 돌려주므로, 이 플래그 없이 시각을 그대로 그리면 목록에 "0:00"이 찍힌다.
    /// 일정은 항상 `true` — 종일 일정은 `kind`가 이미 가른다.
    var hasTime: Bool = true

    /// 완료 인텐트(`CompleteReminderIntent`)에 넘길 EventKit 식별자.
    ///
    /// 표시용 `id`는 반복 회차 구분을 위해 시각을 붙인 합성값이라 인텐트에 못 쓴다.
    /// 일정·표본 항목은 `nil` — 완료 버튼이 붙지 않는 근거가 된다.
    var reminderID: String? = nil

    /// 완료된 미리알림인지. 일정에는 의미가 없어 항상 `false`.
    ///
    /// 완료해도 **오늘 이후 마감이면 계속 보여준다** — 오늘 할 일을 끝냈다는 사실 자체가
    /// 정보다. 지나간 것만 숨겨 위젯이 과거로 채워지는 걸 막는다(→ `WidgetCalendarDataSource`).
    var isCompleted: Bool = false

    /// 이 항목이 날짜 숫자를 빨갛게 칠할 근거인지.
    ///
    /// 판정은 `HolidayEventPolicy`가 하고 `WidgetCalendarDataSource`가 여기 실어 보낸다.
    /// **기기 지역이 한국이 아니면 항상 `false`다** — 공휴일 캘린더의 내용이 지역마다 달라
    /// 한국 밖에서는 믿을 수 없다(그 쪽 주석 참고). 미리알림에는 의미가 없어 항상 `false`.
    var isHoliday: Bool = false

    var isAllDay: Bool { kind == .allDayEvent }

    /// 목록의 시각 줄을 **날짜+요일**로 그릴지(시각 대신) — 종일 일정, 날짜만 지정한 할일.
    var displaysAsDateOnly: Bool { isAllDay || !hasTime }

    /// 목록의 마커를 완료 버튼으로 감쌀지 — 미완료 할일이면서 인텐트에 넘길
    /// EventKit 식별자가 있을 때만. 표본(갤러리)·일정·완료된 항목은 해당 없다.
    var supportsCompletion: Bool { kind == .reminder && reminderID != nil && !isCompleted }

    /// 마감 시각이 지났는데 아직 안 한 할일인지 — 목록의 시각 줄을 빨갛게 칠할 근거.
    ///
    /// 할일만의 개념이다: 시간 일정은 끝나면 목록에서 빠지고(→ `UpcomingItemPicker`),
    /// 오늘 마감 할일은 지나도 남는다 — 남았는데 시각이 평소 색이면 "아직 안 지났다"로
    /// 읽힌다. 날짜만 지정한 할일은 자정이 마감 시각이 아니므로 하루 안에는 늦지 않았다.
    func isOverdue(now: Date) -> Bool {
        kind == .reminder && !isCompleted && hasTime && start < now
    }
}
