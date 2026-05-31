//
//  CalendarEvent.swift
//  cue / Domain
//

import Foundation

/// 캘린더 이벤트 도메인 모델 — EventKit `EKEvent`의 도메인 표현.
///
/// 일정 탭 타임라인이 표시하는 단위. 신규 입력은 `EKEventEditViewController`가
/// 직접 다루므로 이 엔티티에는 노출용으로 필요한 최소 필드만 둔다 — recurrence·
/// location·notes 등 풍부한 필드는 후속 사이클에서 추가.
///
/// `calendarColorHex`는 row 옆에 캘린더 색 점을 그리기 위한 표시용. EventKit
/// `EKCalendar.cgColor`를 "#RRGGBB"로 매핑한 값이며 색을 못 읽으면 nil.
struct CalendarEvent: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarColorHex: String?
}
