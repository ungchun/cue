//
//  AnalyticsService.swift
//  cue / Domain
//

/// 분석 이벤트 기록 경계. 구체 구현은 Firebase(`FirebaseAnalyticsService`) —
/// 프리뷰·테스트는 no-op(`DisabledAnalyticsService`). fire-and-forget이라 동기·논스로잉.
protocol AnalyticsService: Sendable {
    func log(_ event: AnalyticsEvent)
    /// 스키마 밖 raw 전송 — `AnalyticsEvent`(Domain)를 참조할 수 없는 Shared 코드
    /// (잠금화면 Live Activity 인텐트)의 브리지 경로 전용. 앱 코드는 항상 enum 케이스를 쓴다.
    func log(name: String, parameters: [String: String])
}
