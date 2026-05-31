//
//  EventMapper.swift
//  cue / Data
//

import EventKit

/// EventKit 이벤트 모델 ↔ 도메인 엔티티 변환. `ReminderMapper`와 같은 위치의 캘린더 측.
enum EventMapper {
    /// `EKEvent` → 도메인 `CalendarEvent`
    /// 캘린더 색은 `EKCalendar.cgColor`를 "#RRGGBB"로 매핑 — 못 읽으면 nil.
    static func toEvent(_ event: EKEvent) -> CalendarEvent {
        CalendarEvent(
            id: event.eventIdentifier,
            title: event.title ?? "",
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            calendarColorHex: hex(from: event.calendar.cgColor)
        )
    }

    /// `CGColor` → "#RRGGBB" 6자리 hex. RGBA 컴포넌트가 없으면 nil.
    /// EventKit 캘린더 색은 sRGB 가정 — `ReminderMapper.hex`와 동일.
    private static func hex(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(round(max(0, min(1, components[0])) * 255))
        let g = Int(round(max(0, min(1, components[1])) * 255))
        let b = Int(round(max(0, min(1, components[2])) * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
