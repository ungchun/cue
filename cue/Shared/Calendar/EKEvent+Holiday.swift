//
//  EKEvent+Holiday.swift
//  cue / Shared
//

import EventKit

extension EKEvent {
    /// 이 이벤트가 공휴일인지 — 판정 규칙과 근거는 `HolidayEventPolicy`.
    ///
    /// EventKit에서 값을 꺼내는 부분만 여기 둔다. 위젯(`WidgetCalendarDataSource`)과
    /// LA(`LiveMonthCalendarProvider`) 두 곳이 같은 판정을 하므로, 꺼내는 필드 목록이
    /// 갈리지 않도록 한 군데로 모은다.
    var isHolidayEvent: Bool {
        HolidayEventPolicy.isHoliday(
            isSubscribed: calendar.isSubscribed,
            isSubscriptionType: calendar.type == .subscription,
            allowsContentModifications: calendar.allowsContentModifications,
            isAllDay: isAllDay
        )
    }
}
