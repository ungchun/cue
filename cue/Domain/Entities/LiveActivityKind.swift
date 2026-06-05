//
//  LiveActivityKind.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티 종류 — 집중(타이머) / 미리알림(체크리스트) / 일정(이벤트 리스트).
///
/// cue 컨셉상 세 영역만 라이브 액티비티 대상이다. 시스템 한도(앱당 5개, Dynamic Island
/// 표시 2개) 안에서 각 kind는 동시 최대 1개 — 같은 kind로 다시 start하면 구현이 기존
/// 인스턴스를 먼저 end하고 새로 시작한다.
enum LiveActivityKind: String, Sendable, CaseIterable {
    case focus
    case reminder
    case schedule
}
