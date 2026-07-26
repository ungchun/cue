//
//  PriorInstallRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 기존 설치 흔적 감지 — 앱 업데이트로 처음 온보딩을 받은 **기존 사용자**에게
/// 온보딩을 띄우지 않기 위한 판별. 흔적 = 구버전이 남긴 UserDefaults 저장물.
struct PriorInstallRepositoryTests {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test.priorInstall.\(UUID().uuidString)")!
    }

    /// 아무 저장물도 없으면 신규 설치.
    @Test func freshInstallHasNoEvidence() {
        let repo = UserDefaultsPriorInstallRepository(defaults: makeDefaults())
        #expect(repo.hasPriorUsageEvidence() == false)
    }

    /// 구버전이 남긴 저장물이 하나라도 있으면 기존 사용자 — 키별로 각각 검증.
    @Test(arguments: [
        "cue.appSettings.v1",
        "cue.memo.v1",
        "cue.focus.sessions.v1",
        "cue.reminderSort.v1",
        "cue.snapshot.reminders.v1",
        "cue.snapshot.events.v1",
    ])
    func anyLegacyKeyCountsAsEvidence(key: String) {
        let defaults = makeDefaults()
        defaults.set(Data("{}".utf8), forKey: key)
        let repo = UserDefaultsPriorInstallRepository(defaults: defaults)
        #expect(repo.hasPriorUsageEvidence())
    }

    /// 무관한 키는 흔적이 아니다.
    @Test func unrelatedKeyIsNotEvidence() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "some.other.key")
        let repo = UserDefaultsPriorInstallRepository(defaults: defaults)
        #expect(repo.hasPriorUsageEvidence() == false)
    }
}
