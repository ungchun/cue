//
//  FetchStartTabIDUseCaseTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 시작 탭은 **첫 프레임 전에** 알아야 한다(비동기 로드 뒤에 적용하면 기본 탭이 한 번
/// 보였다가 전환된다) — 그래서 동기 경로다. 이 테스트가 그 계약을 고정한다.
struct FetchStartTabIDUseCaseTests {

    /// 저장된 시작 탭을 await 없이 그 자리에서 돌려준다.
    @Test func returnsSavedStartTabSynchronously() async {
        let defaults = UserDefaults(suiteName: "test.startTab.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)
        var settings = AppSettings.default
        settings.startTabID = "reminder"
        await repo.save(settings)

        let sut = FetchStartTabIDUseCase(repository: repo)

        #expect(sut() == "reminder")   // async 대기 없이 동기 반환
    }

    /// 저장값이 없으면 기본 시작 탭(메모).
    @Test func returnsDefaultWhenNothingSaved() {
        let defaults = UserDefaults(suiteName: "test.startTab.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        #expect(FetchStartTabIDUseCase(repository: repo)() == AppSettings.default.startTabID)
        #expect(AppSettings.default.startTabID == "memo")
    }

    /// 동기 경로가 있는 구현이면 심어둔 값을 그대로 읽는다(프리뷰·테스트용 인메모리).
    @Test func readsSeededValueFromInMemoryRepository() {
        var settings = AppSettings.default
        settings.startTabID = "focus"
        let repo = InMemoryAppSettingsRepository(storage: settings)

        #expect(FetchStartTabIDUseCase(repository: repo)() == "focus")
    }

    /// 동기 즉시 읽기는 저장된 설정 **전체**를 준다 — 시작 탭 외 필드도 온전하다.
    @Test func immediateFetchReturnsWholeSettings() async {
        let defaults = UserDefaults(suiteName: "test.startTab.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)
        var settings = AppSettings.default
        settings.startTabID = "schedule"
        settings.colorScheme = .dark
        await repo.save(settings)

        #expect(repo.fetchImmediately() == settings)
    }

    /// 모든 탭의 rawValue가 저장 식별자로 왕복한다 — 설정 화면이 고를 수 있는 값 전부.
    @Test func everyTabRawValueRoundTrips() {
        for tab in AppTab.allCases {
            #expect(AppTab(rawValue: tab.rawValue) == tab)
        }
    }
}
