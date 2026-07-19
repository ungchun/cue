//
//  LiveActivationQuotaTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 무료 사용자의 라이브 활성화 하루 한도(2회, 새로고침 포함) 소진 로직.
struct LiveActivationQuotaTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// 같은 날 소진: 1회차 남은 1 → 2회차 남은 0 → 3회차부터 거부.
    @Test func consumesTwoPerDayThenDenies() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)
        let now = date(2026, 7, 11)

        #expect(await consume(now: now, calendar: calendar) == .allowed(remaining: 1))
        #expect(await consume(now: now, calendar: calendar) == .allowed(remaining: 0))
        #expect(await consume(now: now, calendar: calendar) == .denied)
        #expect(await consume(now: now, calendar: calendar) == .denied)   // 반복 거부 유지
    }

    /// 날짜가 바뀌면 한도가 리셋된다.
    @Test func resetsOnNewDay() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)

        let today = date(2026, 7, 11)
        _ = await consume(now: today, calendar: calendar)
        _ = await consume(now: today, calendar: calendar)
        #expect(await consume(now: today, calendar: calendar) == .denied)

        let tomorrow = date(2026, 7, 12)
        #expect(await consume(now: tomorrow, calendar: calendar) == .allowed(remaining: 1))
    }

    /// 같은 날 자정 직전/직후 경계 — 시각이 달라도 같은 날이면 이어서 카운트.
    @Test func sameDayDifferentHoursShareQuota() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)

        _ = await consume(now: date(2026, 7, 11, hour: 0), calendar: calendar)
        _ = await consume(now: date(2026, 7, 11, hour: 23), calendar: calendar)
        #expect(await consume(now: date(2026, 7, 11, hour: 23), calendar: calendar) == .denied)
    }

    /// Premium이면 소비 없이 무제한 — 사용량도 늘지 않는다.
    @Test func premiumBypassesQuota() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)
        let now = date(2026, 7, 11)

        #expect(await consume(isPremium: true, now: now, calendar: calendar) == .unlimited)
        #expect(await consume(isPremium: true, now: now, calendar: calendar) == .unlimited)
        #expect(await repository.fetch() == .empty)   // 저장소 미변경
    }

    /// UserDefaults 저장소 — 앱 재시작(새 인스턴스)에도 사용량이 이어진다.
    @Test func userDefaultsPersistsAcrossInstances() async {
        let defaults = UserDefaults(suiteName: "test.liveQuota.\(UUID().uuidString)")!
        let now = date(2026, 7, 11)

        let first = ConsumeLiveActivationUseCase(
            repository: UserDefaultsLiveActivationQuotaRepository(defaults: defaults)
        )
        _ = await first(now: now, calendar: calendar)
        _ = await first(now: now, calendar: calendar)

        let second = ConsumeLiveActivationUseCase(
            repository: UserDefaultsLiveActivationQuotaRepository(defaults: defaults)
        )
        #expect(await second(now: now, calendar: calendar) == .denied)
    }
}
