//
//  FocusNotificationScheduling.swift
//  cue / Domain
//

import Foundation

/// 집중 세션의 단계 종료 알림을 예약·취소하는 서비스 추상화.
///
/// 한 번에 하나의 단계 종료 알림만 둔다 — 단계가 끝나거나 일시정지/스킵/중단 시
/// `cancelAll()`로 먼저 비우고, 다음 단계로 넘어갈 때 다시 `schedulePhaseEnd`로 잡는다.
/// 백그라운드에서 단계가 끝나면 시스템이 알림을 발화하고, 앱 복귀 시 ViewModel이
/// 상태를 한 번 추격(catch-up)한다.
///
/// Domain에 두는 이유 — 노티 자체는 UI도 데이터도 아닌 infra지만, ViewModel이 직접
/// `UserNotifications`에 의존하면 SDK가 Presentation·Domain 양쪽에서 끌려 들어와
/// 테스트 fake도 못 만든다. 프로토콜만 Domain에 두고 구현은 Data에서.
protocol FocusNotificationScheduling: Sendable {
    /// 알림 권한 요청. 시스템 prompt가 한 번 뜨고 이후엔 즉시 반환한다.
    /// 실패해도 throw하지 않는다 — 세션 자체는 알림 없이도 작동해야 한다.
    func requestAuthorization() async

    /// `seconds`초 뒤에 발화할 단계 종료 알림을 1건 예약한다.
    /// 같은 카테고리의 이전 pending 알림은 호출 측에서 `cancelAll()`로 먼저 비운다고 가정.
    func schedulePhaseEnd(after seconds: TimeInterval, title: String, body: String)

    /// 이 세션이 예약해 둔 모든 pending 알림을 취소한다.
    /// 일시정지·스킵·중단·단계 전환 직전에 호출한다.
    func cancelAll()
}
