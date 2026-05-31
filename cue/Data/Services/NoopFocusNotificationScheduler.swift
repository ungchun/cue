//
//  NoopFocusNotificationScheduler.swift
//  cue / Data
//

import Foundation

/// 아무 일도 하지 않는 `FocusNotificationScheduling` — 프리뷰·테스트에서 시스템 권한·실
/// 알림 발화 없이 ViewModel을 띄울 때 쓴다.
final class NoopFocusNotificationScheduler: FocusNotificationScheduling {
    func requestAuthorization() async {}
    func schedulePhaseEnd(after seconds: TimeInterval, title: String, body: String) {}
    func cancelAll() {}
}
