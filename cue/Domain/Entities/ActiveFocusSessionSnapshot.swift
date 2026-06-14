//
//  ActiveFocusSessionSnapshot.swift
//  cue / Domain
//

import Foundation

/// 진행 중인 집중 세션의 영속 스냅샷 — 앱이 강제 종료돼 인메모리 `FocusSessionViewModel`이
/// 사라져도, 재실행 시 이 스냅샷으로 세션을 그대로 복원하기 위한 상태 묶음.
///
/// 상태머신을 똑같이 되살리는 데 필요한 최소 정보: 세션 식별/표시(`sessionID`·`title`·
/// `colorHex`), 진행 규칙(`settings`), 현재 진행점(`phase`·`currentCycle`), 그리고 시간.
/// 시간은 **절대 시각**(`phaseStartDate`·`phaseEndDate`)으로 저장해 다운타임이 길어도
/// 벽시계 기준으로 정확히 이어진다. 정지 상태에선 `phaseEndDate`가 멈춰 의미가 없으므로
/// `isPaused` + `remaining`(정지 시점의 잔여)을 함께 실어 복원 시 deadline을 재구성한다.
///
/// 세션이 끝나면(사용자 종료·자연 완료) 스냅샷은 삭제된다 — 저장돼 있다는 것 자체가
/// "복원해야 할 진행 중 세션이 있다"는 뜻이다.
struct ActiveFocusSessionSnapshot: Codable, Equatable, Sendable {
    let sessionID: UUID
    let sessionTitle: String
    let colorHex: String?
    let settings: FocusSettings
    let phase: FocusPhase
    let currentCycle: Int
    /// 현재 phase의 시작 시각(절대). LA timer interval의 lowerBound.
    let phaseStartDate: Date
    /// 현재 phase의 종료 deadline(절대). running이면 이 값이 source of truth.
    let phaseEndDate: Date
    /// 정지 여부. true면 `remaining`이 잔여의 source of truth(`phaseEndDate`는 멈춰 무의미).
    let isPaused: Bool
    /// 정지 시점에 고정된 잔여(초). 복원 시 정지 상태면 이 값으로 deadline을 다시 잡는다.
    let remaining: TimeInterval
}
