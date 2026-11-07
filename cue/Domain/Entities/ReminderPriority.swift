//
//  ReminderPriority.swift
//  cue / Domain
//

import Foundation

/// 미리 알림 우선순위 — Apple 미리 알림 앱의 "없음·낮음·중간·높음" 4단계.
///
/// EventKit은 0~9 정수로 담는다(1~4 높음, 5 중간, 6~9 낮음). 그 세분값은 도메인이
/// 다루지 않고 Data 매퍼가 4단계로 접는다 — 저장 시 단계가 안 바뀌면 원래 정수를 보존한다.
/// 옵셔널 문맥에서 `.none`은 `Optional.none`으로 읽히니 `ReminderPriority.none`으로 쓴다.
enum ReminderPriority: Int, Sendable, Hashable, CaseIterable, Codable {
    case none
    case low
    case medium
    case high
}
