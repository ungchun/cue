//
//  UserNotificationFocusScheduler.swift
//  cue / Data
//

import Foundation
import UserNotifications

/// `FocusNotificationScheduling`의 시스템 구현 — `UNUserNotificationCenter`로 단계 종료
/// 알림을 한 건씩 예약·취소한다.
///
/// 모든 알림은 같은 identifier(`Self.identifier`)를 공유한다 — 한 세션에 단계 종료
/// 알림은 항상 1건만 살아 있어야 하므로, 새 예약이 기존 pending을 자동으로 덮어쓰게
/// 두는 게 가장 안전하다. 단계 전환·일시정지·중단 직전엔 `cancelAll()`을 명시적으로
/// 부른다.
///
/// `final class` + 가변 상태 없음 → 자연스럽게 `Sendable`.
final class UserNotificationFocusScheduler: FocusNotificationScheduling {
    /// 모든 단계 종료 알림이 공유하는 식별자. 같은 id로 add하면 시스템이 이전 pending을
    /// 대체한다 — 굳이 매번 cancel→schedule 두 호출을 강요하지 않아도 안전망이 된다.
    private static let identifier = "cue.focus.phaseEnd"

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
