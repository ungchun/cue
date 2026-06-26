//
//  UserDefaultsMemoRepository.swift
//  cue / Data
//

import Foundation

/// `MemoRepository`의 영속 구현 — `UserDefaults`에 JSON으로 직렬화 저장한다.
///
/// 메모는 하나뿐이라 SwiftData 모델·마이그레이션 부담 없이 가벼운 영속화로 끝낸다.
/// `UserDefaults`는 Apple 문서상 thread-safe이지만 Sendable 어노테이션이 없어
/// `@unchecked Sendable`로 명시. 저장값이 없으면 `Memo.default`를 돌려준다.
struct UserDefaultsMemoRepository: MemoRepository, @unchecked Sendable {
    /// 저장 키 — 스키마 변경 시 `v1`만 올려 자동 마이그레이션(기본값 복귀) 효과.
    private static let storageKey = "cue.memo.v1"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch() async -> Memo {
        guard let data = defaults.data(forKey: Self.storageKey),
              let memo = try? JSONDecoder().decode(Memo.self, from: data) else {
            return .default
        }
        return memo
    }

    func save(_ memo: Memo) async {
        // 인코딩 실패는 거의 없지만, 일어나면 조용히 무시 — 다음 save에서 재시도.
        guard let data = try? JSONEncoder().encode(memo) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}
