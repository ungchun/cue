//
//  CheckForcedUpdateUseCase.swift
//  cue / Domain
//

/// 강제 업데이트 필요 여부 판정 — 현재 버전이 원격 최소 요구 버전보다 낮을 때만 true.
/// 판정 불가(현재 버전 파싱 실패·최소 버전 미설정/조회 실패)는 **false(fail-open)** —
/// 잘못 잠그면 모든 사용자가 앱을 못 쓰므로, 확실한 경우에만 잠근다.
struct CheckForcedUpdateUseCase: Sendable {
    let service: any AppUpdatePolicyService

    func callAsFunction(currentVersion: String) async -> Bool {
        guard let current = AppVersion(currentVersion),
              let minimum = await service.minimumRequiredVersion() else { return false }
        return current < minimum
    }
}
