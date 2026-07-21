//
//  ConsumeLiveActivationUseCase.swift
//  cue / Domain
//

import Foundation

/// 무료 사용자의 라이브 활성화(켜기·새로고침) 1회를 소비한다.
///
/// 한도는 **최초 사용일만 `firstDayLimit`(2회), 이후 매일 `dailyLimit`(1회)** — 첫날 맛보기 후
/// Premium 유도. 날짜가 바뀌면 사용량을 리셋하고, 한도 안이면 소비 후 잔여/한도를 돌려준다.
/// 호출처(ViewModel)는 `.denied`면 LA를 시작하지 않고 Premium 안내로 분기한다.
/// Premium(`isPremium`)이면 소비 없이 `.unlimited` — 조립(CompositionRoot)에서 주입한다.
struct ConsumeLiveActivationUseCase: Sendable {
    let repository: any LiveActivationQuotaRepository

    /// 생애 최초 사용일 하루의 허용 횟수 — 켜기와 새로고침을 구분하지 않는다.
    static let firstDayLimit = 2
    /// 최초 사용일 다음 날부터의 하루 허용 횟수.
    static let dailyLimit = 1

    /// - Parameter isPremium: 호출 시점의 프리미엄 여부. true면 한도를 소비하지 않고 `.unlimited`.
    ///   구매가 런타임에 바뀌므로 생성 시점이 아니라 **호출 시점**에 `PremiumStore`에서 읽어 전달한다.
    func callAsFunction(
        isPremium: Bool = false,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> LiveActivationVerdict {
        guard !isPremium else { return .unlimited }
        let key = Self.dayKey(for: now, calendar: calendar)
        var quota = await repository.fetch()
        if quota.dayKey != key {
            // 날짜 리셋 — 최초 사용일(firstDayKey)은 보존해야 다음 날부터 한도 1이 적용된다.
            quota.dayKey = key
            quota.used = 0
        }
        if quota.firstDayKey == nil { quota.firstDayKey = key }
        let limit = quota.firstDayKey == key ? Self.firstDayLimit : Self.dailyLimit
        guard quota.used < limit else { return .denied }
        quota.used += 1
        await repository.save(quota)
        return .allowed(remaining: limit - quota.used, limit: limit)
    }

    /// 달력 기준 하루 식별자 — 시각과 무관하게 같은 날이면 같은 키.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
