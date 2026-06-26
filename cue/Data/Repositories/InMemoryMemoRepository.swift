//
//  InMemoryMemoRepository.swift
//  cue / Data
//

import Foundation

/// 테스트·프리뷰용 인메모리 `MemoRepository`. 앱이 살아 있는 동안만 보존.
actor InMemoryMemoRepository: MemoRepository {
    private var stored: Memo

    init(memo: Memo = .default) {
        self.stored = memo
    }

    func fetch() -> Memo {
        stored
    }

    func save(_ memo: Memo) {
        stored = memo
    }
}
