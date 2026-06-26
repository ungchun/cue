//
//  MemoRepository.swift
//  cue / Domain
//

import Foundation

/// 단일 `Memo`의 영속 저장소.
///
/// 메모는 하나뿐이라 목록 API 없이 통째로 read/write한다. 저장된 값이 없으면 `fetch`는
/// `Memo.default`(빈 텍스트)를 돌려준다 — 호출처는 nil 분기를 신경 쓰지 않는다.
protocol MemoRepository: Sendable {
    /// 저장된 메모를 불러온다. 없으면 `Memo.default`.
    func fetch() async -> Memo
    /// 메모를 영속 저장 — 기존 값은 덮어쓰기.
    func save(_ memo: Memo) async
}
