//
//  UserDefaultsReviewPromptStateRepository.swift
//  cue / Data
//

import Foundation

/// `ReviewPromptStateRepository`의 UserDefaults 구현 — 한 키에 JSON으로 저장한다.
///
/// Keychain을 쓰는 `LiveActivationQuota`와 달리 재설치로 리셋돼도 무방하다 — 우회해봐야
/// 리뷰 요청을 다시 받을 뿐이고, iOS가 1년 3회로 최종 제한한다. 앱을 지웠다 깐 사용자에게
/// 다시 묻는 것도 부당하지 않다.
struct UserDefaultsReviewPromptStateRepository: ReviewPromptStateRepository, @unchecked Sendable {
    private static let storageKey = "cue.reviewPromptState.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch() async -> ReviewPromptState {
        guard let data = defaults.data(forKey: Self.storageKey),
              let state = try? JSONDecoder().decode(ReviewPromptState.self, from: data)
        else { return .empty }
        return state
    }

    func save(_ state: ReviewPromptState) async {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
