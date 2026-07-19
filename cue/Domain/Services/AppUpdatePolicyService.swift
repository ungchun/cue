//
//  AppUpdatePolicyService.swift
//  cue / Domain
//

/// 앱이 요구하는 최소 버전을 원격에서 조회하는 경계. 구체 구현은 Firebase Remote Config
/// (Data 계층) — Domain은 어디서 오는지 모른다. 조회 실패·미설정이면 nil(잠그지 않음).
protocol AppUpdatePolicyService: Sendable {
    func minimumRequiredVersion() async -> AppVersion?
}
