//
//  InMemoryMemoRepository.swift
//  cue / Data
//

import Foundation

/// 테스트·프리뷰용 인메모리 `MemoRepository`. 앱이 살아 있는 동안만 보존.
actor InMemoryMemoRepository: MemoRepository {
    private var stored: Memo
    /// 테스트 관측용 — 불필요한 write가 없는지 검증한다(InMemoryAppSettingsRepository와 동일 패턴).
    private(set) var saveCount = 0

    init(memo: Memo = .default) {
        self.stored = memo
    }

    func fetch() -> Memo {
        stored
    }

    func save(_ memo: Memo) {
        stored = memo
        saveCount += 1
    }
}
