//
//  UserDefaultsFocusSessionsRepository.swift
//  cue / Data
//

import Foundation

/// `FocusSessionsRepository`의 영속 구현 — `UserDefaults`에 JSON으로 직렬화 저장한다.
///
/// 세션 프리셋은 양이 적어(보통 < 20건) 한 번에 통째로 read/write해도 충분하다. SwiftData
/// 모델·마이그레이션 부담을 피하고 가벼운 영속화로 끝낸다. `UserDefaults`는 thread-safe라
/// actor 없이도 안전.
struct UserDefaultsFocusSessionsRepository: FocusSessionsRepository {
    /// 저장 키 — 스키마 변경 시 `v1` 부분만 올려서 자동 마이그레이션(빈 배열) 효과를 얻는다.
    private static let storageKey = "cue.focus.sessions.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchAll() async -> [FocusSession] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let sessions = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return []
        }
        return sessions
    }

    func save(_ sessions: [FocusSession]) async {
        // 인코딩 실패는 거의 일어나지 않지만, 일어나면 조용히 무시 — 다음 save 호출에서 다시 시도.
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
