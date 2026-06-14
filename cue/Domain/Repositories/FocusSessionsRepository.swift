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

    /// 마지막으로 선택된 세션의 id. 저장된 값이 없거나 잘못된 포맷이면 nil.
    /// "어느 세션이 선택돼 있었는지"는 sessions 목록과 별도 키로 저장한다 — 의미가 다르고
    /// 변경 빈도도 다르며, 한쪽 직렬화 실패가 다른 쪽에 번지지 않게 분리.
    func fetchSelectedSessionID() async -> UUID?
    /// 선택된 세션 id를 영속화. nil이면 저장값을 지운다(=선택 없음 상태 기억).
    func saveSelectedSessionID(_ id: UUID?) async

    /// 진행 중인 세션 스냅샷. 저장된 값이 없거나(=진행 중 세션 없음) 포맷이 깨졌으면 nil.
    /// 프리셋 목록·선택 id와 또 별도 키로 저장 — 변경 빈도(상태 변할 때마다)와 수명이 다르다.
    func fetchActiveSession() async -> ActiveFocusSessionSnapshot?
    /// 진행 중 세션 스냅샷을 영속화. nil이면 저장값을 지운다(=세션 종료/완료).
    func saveActiveSession(_ snapshot: ActiveFocusSessionSnapshot?) async
}
