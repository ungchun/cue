//
//  ConsumeLiveActivationUseCase.swift
//  cue / Domain
//

import Foundation

/// 무료 사용자의 라이브 활성화(켜기·새로고침) 1회를 소비한다 — 하루 `dailyLimit`회.
///
/// 날짜가 바뀌면 사용량을 리셋하고, 한도 안이면 소비 후 잔여 횟수를 돌려준다.
/// 호출처(ViewModel)는 `.denied`면 LA를 시작하지 않고 Premium 안내로 분기한다.
/// Premium(`isPremium`)이면 소비 없이 `.unlimited` — 조립(CompositionRoot)에서 주입한다.
struct ConsumeLiveActivationUseCase: Sendable {
    let repository: any LiveActivationQuotaRepository
    /// Premium이면 한도를 소비하지 않고 `.unlimited`를 돌려준다(기존 라이브/새로고침 토스트 유지).
    var isPremium: Bool = false

    /// 하루 허용 횟수 — 켜기와 새로고침을 구분하지 않는다.
    static let dailyLimit = 2

    func callAsFunction(now: Date = .now, calendar: Calendar = .current) async -> LiveActivationVerdict {
        guard !isPremium else { return .unlimited }
        let key = Self.dayKey(for: now, calendar: calendar)
        var quota = await repository.fetch()
        if quota.dayKey != key {
            quota = LiveActivationQuota(dayKey: key, used: 0)
        }
        guard quota.used < Self.dailyLimit else { return .denied }
        quota.used += 1
        await repository.save(quota)
        return .allowed(remaining: Self.dailyLimit - quota.used)
    }

    /// 달력 기준 하루 식별자 — 시각과 무관하게 같은 날이면 같은 키.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
