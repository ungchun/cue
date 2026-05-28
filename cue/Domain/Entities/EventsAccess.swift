//
//  EventsAccess.swift
//  cue / Domain
//

/// 캘린더 이벤트 접근 권한 상태 — 시스템 권한을 도메인 용어로 표현한다.
/// `RemindersAccess`와 같은 형태 — 미리알림과 캘린더는 EventKit에서 서로 다른 권한.
enum EventsAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case granted
}
