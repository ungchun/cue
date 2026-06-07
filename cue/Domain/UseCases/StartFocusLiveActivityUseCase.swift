//
//  StartFocusLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 집중 세션 라이브 액티비티 시작.
/// `LiveActivityService` 구현이 동일 kind의 기존 인스턴스를 자동 종료 후 새로 시작하므로
/// 호출처(ViewModel)는 토글성 진입을 그대로 가정해도 된다.
struct StartFocusLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction(
        sessionID: UUID,
        sessionTitle: String,
        colorHex: String?,
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date
    ) async throws {
        try await service.startFocus(
            sessionID: sessionID,
            sessionTitle: sessionTitle,
            colorHex: colorHex,
            phase: phase,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate
        )
    }
}
