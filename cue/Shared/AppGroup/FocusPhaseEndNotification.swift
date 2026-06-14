//
//  FocusPhaseEndNotification.swift
//  cue / Shared
//

import Foundation

/// 단계 종료 로컬 알림의 **공유 식별자**.
///
/// 메인 앱의 스케줄러(`UserNotificationFocusScheduler` — 예약·취소)와 LA 인텐트
/// (`EndFocusIntent`·`PauseResumeFocusIntent` — 종료·정지 시 즉시 취소)가 **같은 id**를
/// 가리켜야 서로의 pending 알림을 정확히 지운다. 인텐트는 위젯 익스텐션 타깃에도 컴파일되는데
/// 스케줄러는 앱 타깃 전용이라 그 private 상수를 못 본다 — 그래서 식별자를 양쪽 타깃에서
/// 보이는 Shared에 둔다(한 세션에 단계 종료 알림은 항상 1건이라 단일 식별자로 충분).
enum FocusPhaseEndNotification {
    static let identifier = "cue.focus.phaseEnd"
}
