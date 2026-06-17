//
//  ReminderDynamicIsland.swift
//  cue / Shared
//

import Foundation

/// 미리알림 Live Activity의 표시 로직 — 렌더와 분리해 테스트 가능하게.
enum ReminderDynamicIsland {
    /// 미완료 총개수 = 표시 항목 + 잘려나간 나머지(`remaining`). 잠금화면 우상단 카운트에 쓴다.
    static func incompleteCount(_ state: ReminderLiveActivityAttributes.ContentState) -> Int {
        state.items.count + state.remaining
    }
}
