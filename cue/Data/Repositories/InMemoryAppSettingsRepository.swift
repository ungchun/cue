//
//  InMemoryAppSettingsRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. `actor`로 격리해 `Sendable`을 만족한다.
actor InMemoryAppSettingsRepository: AppSettingsRepository {
    private var storage: AppSettings

    /// 동기 즉시 읽기용 초기 스냅샷 — actor 격리 밖에서 읽을 수 있게 불변으로 둔다.
    /// 동기 경로는 앱 시작 시점 1회(시작 탭 결정)만 쓰이므로 init 값으로 충분하다.
    private nonisolated let seed: AppSettings

    init(storage: AppSettings = .default) {
        self.storage = storage
        self.seed = storage
    }

    /// 저장 호출 횟수 — 테스트가 "불필요한 write 없음"을 검증할 때 읽는다.
    private(set) var saveCount = 0

    func fetch() -> AppSettings { storage }

    nonisolated func fetchImmediately() -> AppSettings? { seed }

    func save(_ settings: AppSettings) {
        storage = settings
        saveCount += 1
    }
}
