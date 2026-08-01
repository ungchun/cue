//
//  EKEvent+Holiday.swift
//  cue / Shared
//

import EventKit

extension EKEvent {
    /// 이 이벤트를 **공휴일로 칠할지** — 판정 규칙과 근거는 `HolidayEventPolicy`.
    ///
    /// 지역 확인을 **먼저** 한다. 한국이 아니면 공휴일 캘린더를 구독하고 있어도 칠하지 않는다
    /// — 지역마다 그 캘린더에 담긴 내용이 달라서다(→ `HolidayEventPolicy`의 한계 주석).
    /// 여기서 막으면 LA ContentState에도 실리지 않아 4KB 예산까지 아낀다.
    ///
    /// EventKit에서 값을 꺼내는 부분만 여기 둔다. 위젯(`WidgetCalendarDataSource`)과
    /// LA(`LiveMonthCalendarProvider`) 두 곳이 같은 판정을 하므로, 꺼내는 필드 목록이
    /// 갈리지 않도록 한 군데로 모은다.
    var showsAsHoliday: Bool {
        guard HolidayEventPolicy.showsHolidayColorHere else { return false }
        return HolidayEventPolicy.isHoliday(
            isSubscribed: calendar.isSubscribed,
            isSubscriptionType: calendar.type == .subscription,
            allowsContentModifications: calendar.allowsContentModifications,
            isAllDay: isAllDay
        )
    }
}
