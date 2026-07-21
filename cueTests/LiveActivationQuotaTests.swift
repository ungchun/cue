//
//  LiveActivationQuotaTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 무료 사용자의 라이브 활성화 한도 — **최초 사용일은 2회, 이후 매일 1회**(새로고침 포함).
struct LiveActivationQuotaTests {

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// 최초 사용일: 1회차 남은 1 → 2회차 남은 0 → 3회차부터 거부. 한도 표기는 2.
    @Test func firstDayAllowsTwoThenDenies() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)
        let now = date(2026, 7, 11)

        #expect(await consume(now: now, calendar: calendar) == .allowed(remaining: 1, limit: 2))
        #expect(await consume(now: now, calendar: calendar) == .allowed(remaining: 0, limit: 2))
        #expect(await consume(now: now, calendar: calendar) == .denied)
        #expect(await consume(now: now, calendar: calendar) == .denied)   // 반복 거부 유지
    }

    /// 최초 사용일 다음 날부터는 하루 1회 — 1회 허용 후 거부. 한도 표기는 1.
    @Test func subsequentDaysAllowOnePerDay() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)

        _ = await consume(now: date(2026, 7, 11), calendar: calendar)   // 최초 사용일 기록

        let nextDay = date(2026, 7, 12)
        #expect(await consume(now: nextDay, calendar: calendar) == .allowed(remaining: 0, limit: 1))
        #expect(await consume(now: nextDay, calendar: calendar) == .denied)

        // 그 다음 날도 동일하게 1회.
        let dayAfter = date(2026, 7, 13)
        #expect(await consume(now: dayAfter, calendar: calendar) == .allowed(remaining: 0, limit: 1))
        #expect(await consume(now: dayAfter, calendar: calendar) == .denied)
    }

    /// 최초 사용일에 2회를 다 안 썼어도 이월되지 않는다 — 다음 날은 그냥 1회.
    @Test func unusedFirstDayAllowanceDoesNotCarryOver() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)

        _ = await consume(now: date(2026, 7, 11), calendar: calendar)   // 첫날 1회만 사용

        let nextDay = date(2026, 7, 12)
        #expect(await consume(now: nextDay, calendar: calendar) == .allowed(remaining: 0, limit: 1))
        #expect(await consume(now: nextDay, calendar: calendar) == .denied)
    }

    /// 같은 날 자정 직전/직후 경계 — 시각이 달라도 같은 날이면 이어서 카운트.
    @Test func sameDayDifferentHoursShareQuota() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)

        _ = await consume(now: date(2026, 7, 11, hour: 0), calendar: calendar)
        _ = await consume(now: date(2026, 7, 11, hour: 23), calendar: calendar)
        #expect(await consume(now: date(2026, 7, 11, hour: 23), calendar: calendar) == .denied)
    }

    /// Premium이면 소비 없이 무제한 — 사용량도 최초 사용일도 기록하지 않는다.
    @Test func premiumBypassesQuota() async {
        let repository = InMemoryLiveActivationQuotaRepository()
        let consume = ConsumeLiveActivationUseCase(repository: repository)
        let now = date(2026, 7, 11)

        #expect(await consume(isPremium: true, now: now, calendar: calendar) == .unlimited)
        #expect(await consume(isPremium: true, now: now, calendar: calendar) == .unlimited)
        #expect(await repository.fetch() == .empty)   // 저장소 미변경
    }

    /// UserDefaults 저장소 — 앱 재시작(새 인스턴스)에도 사용량·최초 사용일이 이어진다.
    @Test func userDefaultsPersistsAcrossInstances() async {
        let defaults = UserDefaults(suiteName: "test.liveQuota.\(UUID().uuidString)")!
        let firstDay = date(2026, 7, 11)

        let first = ConsumeLiveActivationUseCase(
            repository: UserDefaultsLiveActivationQuotaRepository(defaults: defaults)
        )
        _ = await first(now: firstDay, calendar: calendar)
        _ = await first(now: firstDay, calendar: calendar)

        let second = ConsumeLiveActivationUseCase(
            repository: UserDefaultsLiveActivationQuotaRepository(defaults: defaults)
        )
        #expect(await second(now: firstDay, calendar: calendar) == .denied)
        // 재시작 후 다음 날 — 최초 사용일이 보존돼 한도 1이 적용된다.
        #expect(await second(now: date(2026, 7, 12), calendar: calendar) == .allowed(remaining: 0, limit: 1))
    }

    /// 전방 호환 — `firstDayKey`가 없던 옛 저장본은 nil로 디코딩되고,
    /// 다음 소비 날이 최초 사용일로 기록된다(그날 2회).
    @Test func decodesLegacyQuotaWithoutFirstDayKey() throws {
        let legacy = Data(#"{"dayKey":"2026-7-10","used":2}"#.utf8)
        let quota = try JSONDecoder().decode(LiveActivationQuota.self, from: legacy)
        #expect(quota.dayKey == "2026-7-10")
        #expect(quota.used == 2)
        #expect(quota.firstDayKey == nil)
    }
}
