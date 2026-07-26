//
//  UserDefaultsPriorInstallRepository.swift
//  cue / Data
//

import Foundation

/// 구버전이 남긴 UserDefaults 저장물로 기존 설치를 판별한다.
///
/// 검사 키는 **앱 시작만으로는 절대 안 써지는** 것들(설정·메모·집중 프리셋·정렬)과,
/// 시작 프리페치가 쓰는 스냅샷 2종이다 — 스냅샷 경합을 피하려고 이 감지는 RootView
/// `init`(프리페치 task 시작 전)에서 동기로 읽는다. 하나라도 있으면 기존 사용자.
struct UserDefaultsPriorInstallRepository: PriorInstallRepository {
    private let defaults: UserDefaults

    /// 구버전(온보딩 도입 전)이 쓰던 저장 키 — 각 저장소의 storageKey와 동기.
    private static let legacyKeys = [
        "cue.appSettings.v1",
        "cue.memo.v1",
        "cue.focus.sessions.v1",
        "cue.reminderSort.v1",
        "cue.snapshot.reminders.v1",
        "cue.snapshot.events.v1",
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func hasPriorUsageEvidence() -> Bool {
        Self.legacyKeys.contains { defaults.object(forKey: $0) != nil }
    }
}
