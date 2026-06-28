//
//  AppSettingsRepository.swift
//  cue / Domain
//

import Foundation

/// 앱 전역 설정을 영속 저장한다. 단일 인스턴스 — 스코프 없음. 로컬 전용.
protocol AppSettingsRepository: Sendable {
    /// 저장된 설정을 불러온다. 저장된 값이 없으면 `.default`.
    func fetch() async -> AppSettings
    /// 설정을 영속 저장 — 기존 값 덮어쓰기.
    func save(_ settings: AppSettings) async
}
