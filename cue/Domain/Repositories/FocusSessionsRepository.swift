//
//  FocusSessionsRepository.swift
//  cue / Domain
//

import Foundation

/// 사용자가 저장해 둔 `FocusSession` 프리셋 목록의 영속 저장소.
///
/// 세션은 적은 양(보통 5~10개 수준)이라 전체 목록 단위로 read/write한다 —
/// 개별 add/update/delete를 repository에 두지 않고, ViewModel이 메모리 캐시를 갱신한 뒤
/// 전체 리스트를 `save`로 한 번에 덮어쓴다. 구현이 단순해지고 동시성 이슈도 줄어든다.
protocol FocusSessionsRepository: Sendable {
    /// 저장된 모든 세션을 불러온다. 비어 있으면 빈 배열.
    func fetchAll() async -> [FocusSession]
    /// 현재 메모리 상태 그대로 영속 저장 — 기존 데이터는 덮어쓰기.
    func save(_ sessions: [FocusSession]) async
}
