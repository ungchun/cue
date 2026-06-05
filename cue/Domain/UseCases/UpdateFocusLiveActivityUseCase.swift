//
//  UpdateFocusLiveActivityUseCase.swift
//  cue / Domain
//

import Foundation

/// 집중 라이브 액티비티 상태 변경 — 일시정지/재개/스킵/페이즈 전환에서만 호출.
/// 매초 호출 금지(타이머 표시는 시스템 위임 — `Text(timerInterval:pauseTime:)`).
struct UpdateFocusLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction(
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date,
        pauseTime: Date?
    ) async throws {
        try await service.updateFocus(
            phase: phase,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate,
            pauseTime: pauseTime
        )
    }
}
