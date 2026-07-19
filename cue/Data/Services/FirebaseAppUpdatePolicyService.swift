//
//  FirebaseAppUpdatePolicyService.swift
//  cue / Data
//
//  Firebase Remote Config에서 최소 요구 버전을 읽는다. 외부 SDK 경계 글루 — RED 면제.
//  키: `minimum_version` (예: "1.1.0"). 미설정·빈 문자열·네트워크 실패는 모두 nil(잠그지 않음).
//

import FirebaseRemoteConfig

final class FirebaseAppUpdatePolicyService: AppUpdatePolicyService, @unchecked Sendable {
    func minimumRequiredVersion() async -> AppVersion? {
        let config = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        // 1시간 캐시 — 강제 업데이트는 실시간성이 필요 없고, 매 실행 fetch는 쿼터 낭비.
        settings.minimumFetchInterval = 3600
        config.configSettings = settings
        do {
            _ = try await config.fetchAndActivate()
        } catch {
            return nil
        }
        let value = config.configValue(forKey: "minimum_version").stringValue
        return AppVersion(value)
    }
}
