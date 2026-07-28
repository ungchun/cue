//
//  WidgetRangeOffsetStoreTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 좌우 이동형 위젯이 "지금 몇 달/며칠 이동한 상태인지"를 App Group에 들고 다니는 저장소.
///
/// 위젯은 프로세스가 수시로 죽으므로 이동 상태를 메모리에 둘 수 없다. 대신 영속되므로
/// **다음 날이 되면 오늘로 되돌아와야** 한다 — 안 그러면 어제 넘겨둔 달이 계속 남는다.
struct WidgetRangeOffsetStoreTests {

    /// 테스트마다 격리된 suite — 실제 App Group·standard defaults를 건드리지 않는다.
    private func makeStore() -> (WidgetRangeOffsetStore, UserDefaults, String) {
        let suite = "cueTests.widgetOffset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (WidgetRangeOffsetStore(defaults: defaults), defaults, suite)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    // MARK: - 기본 동작

    @Test func startsAtToday() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(store.offset(for: .month, now: date(27), calendar: calendar) == 0)
    }

    @Test func shiftsAccumulate() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 1, for: .month, now: date(27), calendar: calendar)
        let result = store.shift(by: 1, for: .month, now: date(27), calendar: calendar)

        #expect(result == 2)
        #expect(store.offset(for: .month, now: date(27), calendar: calendar) == 2)
    }

    @Test func shiftsGoBothWays() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: -3, for: .month, now: date(27), calendar: calendar)

        #expect(store.offset(for: .month, now: date(27), calendar: calendar) == -3)
    }

    @Test func kindsAreIndependent() {
        // 월 위젯과 3일 위젯을 함께 두어도 서로의 이동에 끌려가지 않는다.
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 2, for: .month, now: date(27), calendar: calendar)

        #expect(store.offset(for: .threeDay, now: date(27), calendar: calendar) == 0)
        #expect(store.offset(for: .oneDay, now: date(27), calendar: calendar) == 0)
    }

    // MARK: - 클램프

    @Test func monthOffsetClampsToOneYearEitherWay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 50, for: .month, now: date(27), calendar: calendar)
        #expect(store.offset(for: .month, now: date(27), calendar: calendar) == 12)

        _ = store.shift(by: -100, for: .month, now: date(27), calendar: calendar)
        #expect(store.offset(for: .month, now: date(27), calendar: calendar) == -12)
    }

    @Test func dayOffsetsClampToAYearOfDays() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 5_000, for: .oneDay, now: date(27), calendar: calendar)

        #expect(store.offset(for: .oneDay, now: date(27), calendar: calendar) == 365)
    }

    // MARK: - 날짜 롤오버

    @Test func offsetResetsWhenTheDayChanges() {
        // 어제 3달 앞으로 넘겨뒀더라도 오늘 열면 이번 달이 보여야 한다.
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 3, for: .month, now: date(27), calendar: calendar)

        #expect(store.offset(for: .month, now: date(28), calendar: calendar) == 0)
    }

    @Test func offsetSurvivesWithinTheSameDay() {
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 3, for: .month, now: date(27, hour: 9), calendar: calendar)

        #expect(store.offset(for: .month, now: date(27, hour: 23), calendar: calendar) == 3)
    }

    @Test func shiftingAfterARolloverStartsFromToday() {
        // 롤오버된 상태에서 이동하면 낡은 오프셋에 더하는 게 아니라 0에서 출발한다.
        let (store, defaults, suite) = makeStore()
        defer { defaults.removePersistentDomain(forName: suite) }

        _ = store.shift(by: 3, for: .month, now: date(27), calendar: calendar)
        let result = store.shift(by: 1, for: .month, now: date(28), calendar: calendar)

        #expect(result == 1)
    }
}
