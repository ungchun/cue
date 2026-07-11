//
//  UserDefaultsLiveActivationQuotaRepository.swift
//  cue / Data
//

import Foundation

/// 라이브 활성화 하루 사용량을 UserDefaults에 JSON으로 저장한다.
/// 깨진 데이터·미저장은 `.empty`(사용량 0)로 폴백 — 사용자에게 불리하지 않게.
struct UserDefaultsLiveActivationQuotaRepository: LiveActivationQuotaRepository, @unchecked Sendable {
    private static let key = "cue.liveActivationQuota.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch() async -> LiveActivationQuota {
        guard let data = defaults.data(forKey: Self.key),
              let quota = try? JSONDecoder().decode(LiveActivationQuota.self, from: data)
        else { return .empty }
        return quota
    }

    func save(_ quota: LiveActivationQuota) async {
        guard let data = try? JSONEncoder().encode(quota) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
