//
//  InMemoryLiveActivationQuotaRepository.swift
//  cue / Data
//

/// 테스트·Preview용 인메모리 사용량 저장소.
actor InMemoryLiveActivationQuotaRepository: LiveActivationQuotaRepository {
    private var storage: LiveActivationQuota

    init(storage: LiveActivationQuota = .empty) {
        self.storage = storage
    }

    func fetch() async -> LiveActivationQuota {
        storage
    }

    func save(_ quota: LiveActivationQuota) async {
        storage = quota
    }
}
