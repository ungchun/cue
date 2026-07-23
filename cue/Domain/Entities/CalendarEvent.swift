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
///
/// `isReadOnly`는 EventKit `EKCalendar.allowsContentModifications == false`를 의미한다.
/// 구독 캘린더(공휴일·외부 ICS 등)는 사용자가 수정할 수 없으므로 탭해도 편집 시트를
/// 띄우지 않는다 — 띄워도 저장이 안 되어 사용자 혼란만 만든다.
struct CalendarEvent: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarColorHex: String?
    var isReadOnly: Bool
    /// 이 이벤트가 속한 캘린더의 식별자(`EKCalendar.calendarIdentifier`). "볼 캘린더 선택"
    /// 필터가 이 값으로 숨긴 캘린더의 이벤트를 걸러낸다. 기본 ""(미상 — 필터에 걸리지 않음).
    var calendarID: String = ""
}
