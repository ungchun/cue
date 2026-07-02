//
//  AppSettingsRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct AppSettingsRepositoryTests {

    /// UserDefaults 구현은 설정을 JSON으로 저장하고 그대로 복원한다.
    @Test func userDefaultsRoundTripsSettings() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        var settings = AppSettings.default
        settings.colorScheme = .dark
        await repo.save(settings)

        #expect(await repo.fetch() == settings)
    }

    /// 저장값이 없으면 기본 설정(.default = 시스템 테마).
    @Test func fetchReturnsDefaultWhenEmpty() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        #expect(await repo.fetch() == .default)
        #expect(AppSettings.default.colorScheme == .system)
    }

    /// 전방 호환: 저장 당시 없던 필드(여기선 전부 누락)는 기본값으로 채워 디코딩된다 —
    /// 설정을 추가해도 옛 저장본이 통째로 날아가지 않는다.
    @Test func decodesForwardCompatiblyFillingMissingKeys() throws {
        let oldData = Data("{}".utf8)  // 아무 키도 없는 옛 저장본
        let settings = try JSONDecoder().decode(AppSettings.self, from: oldData)
        #expect(settings == .default)
    }

    /// 전방 호환: 일부 키만 있는 옛 저장본은 있는 값은 살리고 없는 새 필드만 기본값으로 채운다.
    @Test func decodesPartialJSONKeepingPresentKeys() throws {
        let partial = Data(#"{"colorScheme":"dark"}"#.utf8)  // 화면모드만 저장됐던 시절
        let settings = try JSONDecoder().decode(AppSettings.self, from: partial)
        #expect(settings.colorScheme == .dark)          // 있던 값 유지
        #expect(settings.startTabID == "reminder")      // 새 필드는 기본값
        #expect(settings.focusEndSound == false)
    }

    /// 알 수 없는 값/깨진 데이터면 기본값으로 폴백한다(앱이 죽지 않는다).
    @Test func fetchReturnsDefaultOnCorruptData() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        defaults.set(Data("not json".utf8), forKey: "cue.appSettings.v1")
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        #expect(await repo.fetch() == .default)
    }
}
