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

    // MARK: - App Group 미러 재동기
    //
    // 위젯은 LA 캘린더를 그릴지를 **App Group 미러만 보고** 정한다(위젯은 AppSettings를 못 읽는다).
    // 미러가 `save()`에서만 쓰이면 한 번 어긋난 순간 사용자가 그 토글을 직접 다시 만질 때까지
    // 영구히 틀린 채 남는다 — "설정은 ON인데 LA 캘린더가 안 뜬다"의 정체.
    // 그래서 `fetch()`가 진실(저장값)로 미러를 다시 맞춘다. 방향은 항상 진실→미러 한쪽이다.

    private func makeRepo() -> (UserDefaultsAppSettingsRepository, UserDefaults, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test.appSettings.\(UUID().uuidString)")!
        let group = UserDefaults(suiteName: "test.appGroup.\(UUID().uuidString)")!
        return (UserDefaultsAppSettingsRepository(defaults: defaults, group: group), defaults, group)
    }

    /// 미러가 저장값과 어긋나 있으면(쓰기 유실·다른 프로세스의 도메인 클로버) fetch가 고친다.
    /// 이게 없으면 유료 사용자가 켜둔 캘린더가 위젯에서 영구히 꺼진 채 남는다.
    @Test func fetchRepairsStaleMirror() async {
        let (repo, _, group) = makeRepo()
        var settings = AppSettings.default
        settings.reminderShowsCalendar = true
        settings.scheduleShowsCalendar = true
        await repo.save(settings)

        // 외부 원인으로 미러만 꺼진 상태를 재현.
        group.set(false, forKey: SharedAppGroup.Keys.reminderShowsCalendar)
        group.set(false, forKey: SharedAppGroup.Keys.scheduleShowsCalendar)

        _ = await repo.fetch()

        #expect(group.bool(forKey: SharedAppGroup.Keys.reminderShowsCalendar) == true)
        #expect(group.bool(forKey: SharedAppGroup.Keys.scheduleShowsCalendar) == true)
    }

    /// 반대 방향(미러만 켜져 있음)도 고친다 — 저장값이 꺼졌는데 미러가 켜진 채면
    /// 무료 사용자에게 유료 표시가 새고, 설정 화면과 잠금화면이 서로 다른 말을 한다.
    @Test func fetchClearsMirrorLeftOnWhenSettingIsOff() async {
        let (repo, _, group) = makeRepo()
        await repo.save(.default)                                            // 전부 off
        group.set(true, forKey: SharedAppGroup.Keys.memoShowsCalendar)        // 미러만 켜진 상태

        _ = await repo.fetch()

        #expect(group.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar) == false)
    }

    /// 저장값이 아예 없는 첫 실행에서도 미러를 기본값으로 심는다 — 미러가 비어 있으면
    /// 위젯이 읽는 값(`memoTextSize` 등)이 저장값과 다른 채로 시작한다.
    @Test func fetchSeedsMirrorOnFirstLaunch() async {
        let (repo, _, group) = makeRepo()

        #expect(await repo.fetch() == .default)

        #expect(group.string(forKey: SharedAppGroup.Keys.memoTextSize) == AppSettings.default.memoTextSize.rawValue)
        #expect(group.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar) == false)
    }

    /// 숨긴 캘린더 목록도 미러 재동기 대상 — LA 월간 캘린더 점이 이 목록으로 걸러진다.
    @Test func fetchRepairsHiddenCalendarMirror() async {
        let (repo, _, group) = makeRepo()
        var settings = AppSettings.default
        settings.hiddenCalendarIDs = ["cal-work"]
        await repo.save(settings)

        group.set(["cal-stale"], forKey: SharedAppGroup.Keys.hiddenCalendarIDs)

        _ = await repo.fetch()

        #expect(group.stringArray(forKey: SharedAppGroup.Keys.hiddenCalendarIDs) == ["cal-work"])
    }

    /// 숨긴 **할일 목록**도 미러 대상 — 홈 위젯이 미리알림을 거를 때 이 값을 읽는다.
    ///
    /// 이게 없어서 위젯만 설정을 못 따라갔다: 앱·LA는 `AppSettings`를 직접 읽어 정상이었지만
    /// 별도 프로세스인 위젯은 미러밖에 볼 수 없는데 이 키가 실리지 않았다. 그래서 체크를
    /// 해제한 목록의 할일이 위젯에 계속 떴다.
    @Test func fetchRepairsHiddenReminderListMirror() async {
        let (repo, _, group) = makeRepo()
        var settings = AppSettings.default
        settings.hiddenReminderListIDs = ["list-personal"]
        await repo.save(settings)

        group.set(["list-stale"], forKey: SharedAppGroup.Keys.hiddenReminderListIDs)

        _ = await repo.fetch()

        #expect(group.stringArray(forKey: SharedAppGroup.Keys.hiddenReminderListIDs) == ["list-personal"])
    }

    /// 재동기 여부를 가르는 판정 — fetch는 화면 진입마다 불리므로, 맞을 때는 쓰지 않아야
    /// 한다(같은 App Group 도메인을 쓰는 위젯 프로세스와 무의미하게 경합하지 않게).
    @Test func mirrorMatchesDetectsDivergence() async {
        let (repo, _, group) = makeRepo()
        var settings = AppSettings.default
        settings.memoShowsCalendar = true
        settings.memoTextSize = .small
        settings.hiddenCalendarIDs = ["cal-work"]
        settings.hiddenReminderListIDs = ["list-personal"]

        #expect(repo.mirrorMatches(settings) == false)   // 미러 비어 있음 → 재동기 필요
        await repo.save(settings)
        #expect(repo.mirrorMatches(settings) == true)    // 저장으로 맞춰짐 → 재동기 불필요

        group.set(false, forKey: SharedAppGroup.Keys.memoShowsCalendar)
        #expect(repo.mirrorMatches(settings) == false)   // 한 키만 어긋나도 감지

        await repo.save(settings)
        group.set(["list-stale"], forKey: SharedAppGroup.Keys.hiddenReminderListIDs)
        #expect(repo.mirrorMatches(settings) == false)   // 할일 목록 키도 판정에 포함
    }
}
