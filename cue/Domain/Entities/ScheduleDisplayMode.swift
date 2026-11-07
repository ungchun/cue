//
//  ScheduleDisplayMode.swift
//  cue / Domain
//

/// 일정 탭 본문 표시 방식 — 다가오는 일정 타임라인(기본) 또는 월간 캘린더.
/// 마지막 선택을 저장해 앱을 다시 열어도 그 모드로 시작한다 — rawValue가 저장 식별자라 케이스 이름을 바꾸지 않는다.
enum ScheduleDisplayMode: String, Sendable, Equatable {
    case timeline
    case month
}
