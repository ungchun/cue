//
//  LiveActivityRefreshSourceTests.swift
//  cueTests
//
//  캘린더 토글 재게시가 어떤 항목 목록을 쓰는지 — 체크로 지운 항목이 되살아나면 안 된다.
//

import Foundation
import Testing
@testable import cue

/// `refreshLayout()`이 쓸 항목 목록을 고르는 규칙.
///
/// **왜 보관본이 있나** — 잠금화면 캘린더를 껐다 켜면 화면에 실리는 항목 수가 달라진다
/// (캘린더가 자리를 먹으면 cap이 줄어든다). 게시된 cap된 목록에서 다시 계산하면 껐을 때
/// 항목이 영영 안 돌아오므로, 게시 시점의 **미-cap 원본**을 따로 보관해 거기서 복원한다.
///
/// **문제** — LA 체크(`CompleteReminderIntent`)는 서비스를 거치지 않고 `Activity`를 직접
/// 갱신한다. 그래서 보관본은 그 삭제를 모른 채 지운 항목을 계속 들고 있고, 이후 캘린더를
/// 토글하면 **완료한 할일이 카드에 되살아난다**.
struct LiveActivityRefreshSourceTests {

    private func item(_ id: String) -> LiveReminderItem {
        LiveReminderItem(id: id, title: id, colorHex: nil)
    }

    // MARK: - 재현: 체크로 지운 항목이 되살아난다

    /// **재현 핵심.** 보관본에는 있는데 현재 화면에 없는 항목 = 체크로 지워진 것.
    /// 복원 대상에서 빠져야 한다.
    @Test func checkedItemIsNotRestoredFromBackup() {
        let backup = [item("a"), item("b"), item("c")]   // 게시 시점 원본
        let onScreen = [item("a"), item("c")]            // b를 체크해서 지운 뒤

        let source = LiveActivityRefreshSource.reminderItems(backup: backup, onScreen: onScreen)

        #expect(source.map(\.id) == ["a", "c"], "체크로 지운 항목이 재게시에서 되살아난다")
    }

    /// 캘린더가 켜져 cap된 경우 — 화면엔 앞 2개뿐이어도 보관본의 나머지는 살아야 한다.
    /// 여기가 보관본의 존재 이유다. 지운 것만 빼고 cap된 것은 되돌려야 한다.
    ///
    /// 화면에 남은 항목이 보관본의 **접두(prefix)** 면 cap으로 잘린 것이고,
    /// 중간이 빠졌으면 체크로 지워진 것이다 — 이 둘을 구분해야 한다.
    @Test func cappedItemsAreStillRestored() {
        let backup = [item("a"), item("b"), item("c"), item("d")]
        let onScreen = [item("a"), item("b")]            // cap으로 잘림(접두)

        let source = LiveActivityRefreshSource.reminderItems(backup: backup, onScreen: onScreen)

        #expect(source.map(\.id) == ["a", "b", "c", "d"], "cap으로 잘린 항목이 복원되지 않는다")
    }

    /// 체크와 cap이 겹친 경우 — b를 지웠고 나머지는 cap으로 잘렸다.
    /// 지운 b만 빼고 잘린 것들은 복원한다.
    @Test func checkedItemExcludedWhileCappedRestored() {
        let backup = [item("a"), item("b"), item("c"), item("d")]
        let onScreen = [item("a"), item("c")]            // b 체크, d는 cap

        let source = LiveActivityRefreshSource.reminderItems(backup: backup, onScreen: onScreen)

        #expect(source.map(\.id) == ["a", "c", "d"])
    }

    /// 보관본이 비었으면(앱 재시작으로 유실) 화면 목록을 그대로 쓴다 — 기존 동작.
    @Test func emptyBackupFallsBackToOnScreen() {
        let onScreen = [item("a"), item("b")]

        let source = LiveActivityRefreshSource.reminderItems(backup: [], onScreen: onScreen)

        #expect(source.map(\.id) == ["a", "b"])
    }

    /// 전부 체크해서 화면이 비었으면 아무것도 복원하지 않는다.
    @Test func allCheckedRestoresNothing() {
        let backup = [item("a"), item("b")]

        let source = LiveActivityRefreshSource.reminderItems(backup: backup, onScreen: [])

        #expect(source.isEmpty)
    }
}
