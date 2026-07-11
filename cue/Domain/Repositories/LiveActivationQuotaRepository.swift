//
//  LiveActivationQuotaRepository.swift
//  cue / Domain
//

/// 라이브 활성화 하루 사용량 영속화 — 구현은 Data(UserDefaults/인메모리).
protocol LiveActivationQuotaRepository: Sendable {
    func fetch() async -> LiveActivationQuota
    func save(_ quota: LiveActivationQuota) async
}
