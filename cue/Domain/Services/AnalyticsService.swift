//
//  AnalyticsService.swift
//  cue / Domain
//

/// 분석 이벤트 기록 경계. 구체 구현은 Firebase(`FirebaseAnalyticsService`) —
/// 프리뷰·테스트는 no-op(`DisabledAnalyticsService`). fire-and-forget이라 동기·논스로잉.
protocol AnalyticsService: Sendable {
    func log(_ event: AnalyticsEvent)
}
