//
//  FetchStartTabIDUseCase.swift
//  cue / Domain
//

import Foundation

/// 앱 시작 시 처음 보여줄 탭의 식별자를 **동기로** 읽는다.
///
/// 왜 동기인가 — 시작 탭은 첫 프레임을 그리기 **전에** 정해져야 한다. 비동기
/// `FetchAppSettingsUseCase`로 읽으면 기본 탭(메모)이 한 번 그려진 뒤 전환돼,
/// 사용자가 지정한 탭이 "잠깐 다른 화면 → 내 탭"으로 보인다.
/// 동기 경로가 없는 저장소(원격 등)라면 기본값으로 진행한다.
struct FetchStartTabIDUseCase: Sendable {
    let repository: any AppSettingsRepository

    func callAsFunction() -> String {
        repository.fetchImmediately()?.startTabID ?? AppSettings.default.startTabID
    }
}
