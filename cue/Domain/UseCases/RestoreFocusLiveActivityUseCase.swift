//
//  RestoreFocusLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 앱 재실행 시 진행 중 세션의 라이브 액티비티를 복원한다. 구현이 살아있는 기존
/// 인스턴스를 채택(재연결)하거나, 없으면 새로 시작한다 — 호출처(복원 세션)는 그 분기를
/// 신경 쓰지 않고 "복원" 의도만 표현한다.
struct RestoreFocusLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction(
        sessionID: UUID,
        sessionTitle: String,
        colorHex: String?,
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date,
        pauseTime: Date?
    ) async throws {
        try await service.restoreFocus(
            sessionID: sessionID,
            sessionTitle: sessionTitle,
            colorHex: colorHex,
            phase: phase,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate,
            pauseTime: pauseTime
        )
    }
}
