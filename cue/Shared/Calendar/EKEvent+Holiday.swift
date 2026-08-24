//
//  EKEvent+Holiday.swift
//  cue / Shared
//

import EventKit

extension EKEvent {
    /// 이 이벤트를 **빨간 날짜로 칠할지** — 판정 규칙과 근거는 `HolidayEventPolicy`.
    ///
    /// EventKit에서 값을 꺼내는 부분만 여기 둔다. 위젯도 LA도 `WidgetCalendarDataSource`
    /// 하나를 거쳐 이 값을 받으므로, 꺼내는 필드 목록이 갈릴 자리를 남기지 않는다.
    ///
    /// 한국 기기가 아니면 여기서 곧장 `false`가 되어 LA ContentState에도 실리지 않는다.
    var showsAsHoliday: Bool {
        HolidayEventPolicy.showsAsHoliday(
            regionCode: Locale.current.region?.identifier,
            calendarTitle: calendar.title,
            isAllDay: isAllDay
        )
    }
}
