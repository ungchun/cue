//
//  EventCalendar.swift
//  cue / Domain
//

/// 캘린더(달력) — iOS "캘린더" 앱의 캘린더 하나에 대응하는 도메인 엔티티.
/// 미리알림의 `ReminderList`에 대응하는 일정 측 타입. 설정에서 "볼 캘린더 선택"
/// 체크리스트를 그리는 데 쓴다.
struct EventCalendar: Identifiable, Equatable, Sendable {
    let id: String
    var title: String
    var colorHex: String?
}
