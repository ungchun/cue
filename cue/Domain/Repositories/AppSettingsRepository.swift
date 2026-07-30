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

    /// **동기** 즉시 읽기 — 첫 프레임 전에 값이 필요한 경우(시작 탭)를 위한 경로.
    /// 비동기 `fetch()`를 await하면 첫 body가 이미 그려진 뒤라 기본값이 한 번 보인다.
    /// 동기로 읽을 수 없는 구현은 `nil`을 돌려 호출부가 기본값으로 진행하게 한다.
    func fetchImmediately() -> AppSettings?
}
