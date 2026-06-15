//
//  ReminderLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 미리알림 라이브 액티비티의 attributes.
///
/// `listTitle`(예: "오늘", "장보기")은 시작 시 결정되고 활성 중엔 변하지 않으므로 attributes에.
/// 표시 항목·남은 개수는 사용자 동작(완료 토글·항목 추가/삭제)에 따라 갱신되므로 ContentState.
///
/// 시간 흐름과 무관 — `staleDate`는 service 구현에서 nil 또는 매우 멀리 둔다.
struct ReminderLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var items: [LiveReminderItem]
        var remaining: Int
    }

    let listTitle: String
}

extension ReminderLiveActivityAttributes.ContentState {
    /// `id` 항목을 제거한 새 상태. LA에서 체크(완료)한 항목을 숨길 때 쓴다.
    /// 표시 카운트(`items.count + remaining`)는 항목이 빠진 만큼 자동으로 줄어든다.
    /// `remaining`은 그대로 둔다 — 잘려나간 나머지 항목의 데이터가 LA엔 없어 backfill 불가.
    func removingItem(id: String) -> Self {
        var copy = self
        copy.items.removeAll { $0.id == id }
        return copy
    }
}
