//
//  ReminderSortRepository.swift
//  cue / Domain
//

import Foundation

/// 미리알림 섹션별 정렬 설정(+수동 순서)을 영속 저장한다. EventKit이 이 정보를
/// 제공하지 않으므로 앱이 로컬에 따로 보관한다. 스코프 키는 ViewModel이 만든다 —
/// 오늘은 `"today"`, 개별 리스트는 `"list:<listID>"`.
protocol ReminderSortRepository: Sendable {
    /// 해당 스코프의 정렬 설정을 불러온다. 저장된 값이 없으면 `.default`.
    func fetch(scope: String) async -> ReminderSortSettings
    /// 정렬 설정을 영속 저장 — 기존 값 덮어쓰기.
    func save(_ settings: ReminderSortSettings, scope: String) async
}
