//
//  ReminderSortRepositoryTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct ReminderSortRepositoryTests {

    /// UserDefaults 구현은 스코프별 설정을 JSON으로 저장하고 그대로 복원한다.
    @Test func userDefaultsRoundTripsSettingsPerScope() async {
        let defaults = UserDefaults(suiteName: "test.reminderSort.\(UUID().uuidString)")!
        let repo = UserDefaultsReminderSortRepository(defaults: defaults)

        let settings = ReminderSortSettings(
            preference: .init(field: .title, direction: .descending),
            manualOrder: ["x", "y", "z"]
        )
        await repo.save(settings, scope: "list:A")

        #expect(await repo.fetch(scope: "list:A") == settings)
        // 다른 스코프는 영향 없이 기본값.
        #expect(await repo.fetch(scope: "today") == .default)
    }

    /// 한 스코프 저장이 다른 스코프를 덮어쓰지 않는다(같은 키 맵에 공존).
    @Test func userDefaultsKeepsMultipleScopesIndependent() async {
        let defaults = UserDefaults(suiteName: "test.reminderSort.\(UUID().uuidString)")!
        let repo = UserDefaultsReminderSortRepository(defaults: defaults)

        let today = ReminderSortSettings(
            preference: .init(field: .dueDate, direction: .ascending), manualOrder: []
        )
        let listA = ReminderSortSettings(
            preference: .init(field: .creationDate, direction: .descending), manualOrder: ["1"]
        )
        await repo.save(today, scope: "today")
        await repo.save(listA, scope: "list:A")

        #expect(await repo.fetch(scope: "today") == today)
        #expect(await repo.fetch(scope: "list:A") == listA)
    }

    /// 저장값이 없으면 기본 정렬(.default = 수동·오름차순).
    @Test func fetchReturnsDefaultWhenEmpty() async {
        let defaults = UserDefaults(suiteName: "test.reminderSort.\(UUID().uuidString)")!
        let repo = UserDefaultsReminderSortRepository(defaults: defaults)

        #expect(await repo.fetch(scope: "list:Z") == .default)
        #expect(ReminderSortSettings.default.preference.field == .manual)
    }
}
