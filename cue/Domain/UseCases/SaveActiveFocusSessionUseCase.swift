//
//  SaveActiveFocusSessionUseCase.swift
//  cue / Domain
//

import Foundation

/// 진행 중 집중 세션 스냅샷을 영속 저장. 세션 상태머신이 상태를 바꿀 때마다(시작·단계
/// 전환·정지·재개) 호출해 최신 상태를 박아둔다. nil을 주면 저장값을 지운다 — 세션
/// 종료/완료 시 호출해 "복원할 세션 없음" 상태로 만든다.
struct SaveActiveFocusSessionUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction(_ snapshot: ActiveFocusSessionSnapshot?) async {
        await repository.saveActiveSession(snapshot)
    }
}
