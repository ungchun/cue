//
//  DetectPriorInstallUseCase.swift
//  cue / Domain
//

import Foundation

/// 기존 설치 흔적 감지 — 얇은 래퍼. 온보딩 표시 판정(`OnboardingViewModel.launchDecision`)의 입력.
struct DetectPriorInstallUseCase: Sendable {
    let repository: any PriorInstallRepository

    func callAsFunction() -> Bool {
        repository.hasPriorUsageEvidence()
    }
}
