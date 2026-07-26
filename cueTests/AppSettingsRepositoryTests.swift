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
        #expect(settings.startTabID == "memo")          // 새 필드는 기본값(시작 탭 = 메모)
        #expect(settings.focusEndSound == false)
        #expect(settings.memoShowsCalendar == false)    // 캘린더 표시 플래그도 기본 false
        #expect(settings.scheduleShowsCalendar == false)
        #expect(settings.liveAlwaysOn == false)         // 항상 표시 기본 off
        #expect(settings.liveAlwaysOnMemo == true)      // 하위 종류 기본 on
        #expect(settings.liveAlwaysOnReminder == true)
        #expect(settings.liveAlwaysOnSchedule == true)
        #expect(settings.liveAlwaysOnReminderScopeID == "all")   // 할일 범위 기본 전체
        #expect(settings.tasksDefaultScopeID == "all")           // 할일 탭 기본 화면도 전체
        #expect(settings.hiddenCalendarIDs.isEmpty)              // 숨긴 캘린더 기본 없음(전부 표시)
        #expect(settings.hasCompletedOnboarding == false)        // 온보딩 완주 기본 false(첫 실행 표시)
        #expect(settings.hasStartedOnboarding == false)          // 온보딩 시작 마커 기본 false
    }

    /// 숨긴 캘린더 집합이 저장·복원 왕복에서 보존된다.
    @Test func userDefaultsRoundTripsHiddenCalendars() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        var settings = AppSettings.default
        settings.hiddenCalendarIDs = ["cal-work", "cal-holidays"]
        await repo.save(settings)

        #expect(await repo.fetch().hiddenCalendarIDs == ["cal-work", "cal-holidays"])
    }

    /// 할일 탭 기본 화면 스코프가 저장·복원 왕복에서 보존된다.
    @Test func userDefaultsRoundTripsTasksDefaultScope() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        var settings = AppSettings.default
        settings.tasksDefaultScopeID = "today"
        await repo.save(settings)

        #expect(await repo.fetch().tasksDefaultScopeID == "today")
    }

    /// 캘린더 표시 플래그가 저장·복원 왕복에서 true로 보존된다.
    @Test func userDefaultsRoundTripsCalendarFlags() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        var settings = AppSettings.default
        settings.memoShowsCalendar = true
        settings.scheduleShowsCalendar = true
        await repo.save(settings)

        let fetched = await repo.fetch()
        #expect(fetched.memoShowsCalendar == true)
        #expect(fetched.scheduleShowsCalendar == true)
    }

    /// 알 수 없는 값/깨진 데이터면 기본값으로 폴백한다(앱이 죽지 않는다).
    @Test func fetchReturnsDefaultOnCorruptData() async {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        defaults.set(Data("not json".utf8), forKey: "cue.appSettings.v1")
        let repo = UserDefaultsAppSettingsRepository(defaults: defaults)

        #expect(await repo.fetch() == .default)
    }
}
