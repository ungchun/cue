//
//  RemindersAccess.swift
//  cue / Domain
//

/// 미리 알림 접근 권한 상태 — 시스템 권한을 도메인 용어로 표현한다.
enum RemindersAccess: Equatable, Sendable {
    case notDetermined
    case denied
    case granted
}
