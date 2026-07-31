//
//  LiveActivityRefreshSource.swift
//  cue / Shared
//

import Foundation

/// 캘린더 토글 재게시(`refreshLayout`)가 쓸 항목 목록을 고르는 규칙.
///
/// **보관본이 있는 이유** — 잠금화면 캘린더를 켜면 자리를 먹어 실을 수 있는 항목 수가 준다
/// (`fittedReminderState`의 cap 사다리). 게시된 cap된 목록에서 다시 계산하면 캘린더를 껐을 때
/// 잘려나간 항목이 영영 안 돌아오므로, 게시 시점의 **미-cap 원본**을 따로 보관해 복원한다.
///
/// **왜 그냥 보관본을 쓰면 안 되나** — LA 체크(`CompleteReminderIntent`)는 서비스를 거치지
/// 않고 `Activity`를 직접 갱신한다. 보관본은 그 삭제를 모르므로, 그대로 복원하면 완료한
/// 할일이 카드에 되살아난다.
///
/// 그래서 두 목록을 대조한다: 보관본에 있는데 화면에 없으면 **체크로 지워진 것**이고,
/// 화면 끝 이후의 것들은 **cap으로 잘린 것**이다. 앞의 것만 빼고 뒤의 것은 되돌린다.
enum LiveActivityRefreshSource {

    /// 재게시에 실을 할일 항목 — 체크로 지운 것은 빼고, cap으로 잘린 것은 복원한다.
    ///
    /// - Parameters:
    ///   - backup: 게시 시점에 보관한 미-cap 원본.
    ///   - onScreen: 지금 LA에 실려 있는 목록(체크 삭제가 반영된 최신).
    static func reminderItems(
        backup: [LiveReminderItem],
        onScreen: [LiveReminderItem]
    ) -> [LiveReminderItem] {
        // 보관본이 없으면(앱 재시작으로 유실) 화면이 유일한 진실이다.
        guard !backup.isEmpty else { return onScreen }
        // 화면이 비었으면 전부 체크한 것 — 되살릴 게 없다. (cap이 0이 되는 일은 없다:
        // 사다리 최소가 3이고, 그조차 못 맞추면 `min(3, count)`로 최소 1개는 남는다.)
        guard let last = onScreen.last else { return [] }
        // 화면에 남은 id 집합 — 체크로 지워진 것을 가려내는 기준.
        let surviving = Set(onScreen.map(\.id))
        // 화면 마지막 항목이 보관본의 어디인지 — 그 뒤는 cap으로 잘린 구간이라 되살린다.
        let cappedFrom = backup.firstIndex { $0.id == last.id }.map { $0 + 1 } ?? backup.count
        return backup.enumerated()
            .filter { surviving.contains($0.element.id) || $0.offset >= cappedFrom }
            .map(\.element)
    }
}
