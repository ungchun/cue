//
//  UserNotificationFocusScheduler.swift
//  cue / Data
//

import Foundation
import UserNotifications

/// `FocusNotificationScheduling`의 시스템 구현 — `UNUserNotificationCenter`로 단계 종료
/// 알림을 한 건씩 예약·취소한다.
///
/// 모든 알림은 같은 identifier(`FocusPhaseEndNotification.identifier`)를 공유한다 — 한 세션에
/// 단계 종료 알림은 항상 1건만 살아 있어야 하므로, 새 예약이 기존 pending을 자동으로
/// 덮어쓰게 두는 게 가장 안전하다. 단계 전환·일시정지·중단 직전엔 `cancelAll()`을 명시적으로
/// 부른다. LA 인텐트(종료·정지)도 같은 식별자로 즉시 취소하므로 Shared 상수로 둔다.
///
/// `final class` + 가변 상태 없음 → 자연스럽게 `Sendable`.
final class UserNotificationFocusScheduler: FocusNotificationScheduling {
    private static var identifier: String { FocusPhaseEndNotification.identifier }

    func requestAuthorization() async {
        // 실패해도 throw하지 않는다 — 거절돼도 세션은 알림 없이 계속 동작해야 한다.
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    func schedulePhaseEnd(after seconds: TimeInterval, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // `UNTimeIntervalNotificationTrigger`는 0초를 허용하지 않으므로 최소 1초로 클램프.
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, seconds), repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.identifier, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelAll() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}
