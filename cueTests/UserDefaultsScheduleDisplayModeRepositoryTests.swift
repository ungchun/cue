//
//  UserDefaultsScheduleDisplayModeRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct UserDefaultsScheduleDisplayModeRepositoryTests {

    private static let key = "cue.scheduleDisplayMode.v1"

    /// 테스트마다 격리된 UserDefaults — 표준 저장소를 오염시키지 않는다.
    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "test.scheduleDisplayMode.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }

    /// 저장한 적 없으면 nil — 호출부가 기본 모드(타임라인)로 대체한다.
    @Test func fetchReturnsNilWhenNothingSaved() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(UserDefaultsScheduleDisplayModeRepository(defaults: defaults).fetch() == nil)
    }

    /// 두 모드 모두 저장 후 그대로 읽힌다.
    @Test func saveThenFetchRoundTripsEveryMode() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repo = UserDefaultsScheduleDisplayModeRepository(defaults: defaults)

        repo.save(.month)
        #expect(repo.fetch() == .month)

        repo.save(.timeline)
        #expect(repo.fetch() == .timeline)
    }

    /// 새 인스턴스(= 앱 재실행)도 같은 defaults에서 저장값을 읽는다.
    @Test func savedModeSurvivesNewRepositoryInstance() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        UserDefaultsScheduleDisplayModeRepository(defaults: defaults).save(.month)

        #expect(UserDefaultsScheduleDisplayModeRepository(defaults: defaults).fetch() == .month)
    }

    /// 모르는 문자열(옛/깨진 데이터)이면 크래시 없이 nil.
    @Test func fetchReturnsNilForUnknownRawValue() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("year", forKey: Self.key)

        #expect(UserDefaultsScheduleDisplayModeRepository(defaults: defaults).fetch() == nil)
    }

    /// 문자열이 아닌 타입이 들어 있어도 nil.
    @Test func fetchReturnsNilForNonStringValue() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(42, forKey: Self.key)

        #expect(UserDefaultsScheduleDisplayModeRepository(defaults: defaults).fetch() == nil)
    }
}
