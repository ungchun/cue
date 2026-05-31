//
//  FocusPhase.swift
//  cue / Domain
//

/// 집중 세션의 단계. 한 사이클은 `focus`로 시작해 (반복 세션이면) `rest`로 끝난다.
enum FocusPhase: Equatable, Sendable {
    /// 집중 — 사용자가 일하고 있는 단계.
    case focus
    /// 휴식 — 다음 집중 전 짧은 휴식. 비반복 세션엔 등장하지 않는다.
    case rest
}
