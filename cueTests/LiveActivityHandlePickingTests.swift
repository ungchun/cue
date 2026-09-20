//
//  LiveActivityHandlePickingTests.swift
//  cueTests
//
//  살아있는 LA 인스턴스를 고르는 규칙 — 죽은 인스턴스에 update하면 조용히 무시된다.
//

import Foundation
import Testing
@testable import cue

/// `Activity.activities`에서 **어느 인스턴스를 쓸지** 고르는 규칙.
///
/// 증상(2026-07-31 보고): 갓 켠 LA에서 할일을 체크하면 잘 사라지는데, 시간이 한참 지난
/// LA에서는 체크해도 카드가 그대로였다. 순정 미리알림 앱에는 완료로 반영돼 있었다 —
/// 즉 EventKit 저장은 성공했고 **LA 화면 갱신만** 실패했다.
///
/// 원인 — `Activity.activities`는 `.active`만 담지 않는다. 시스템이 종료한
/// (`.ended`) · 사용자가 치운(`.dismissed`) · 오래된(`.stale`) 인스턴스도 함께 들어 있고,
/// `.first`는 정렬을 보장하지 않는다. 죽은 인스턴스를 잡으면 `update()`가 **예외도 없이
/// 무시**되어, 코드는 성공한 것처럼 끝나고 화면만 그대로 남는다.
///
/// 갓 켠 LA가 정상이었던 이유는 그때는 살아있는 인스턴스 하나뿐이라 `.first`가 반드시
/// 맞는 것을 잡았기 때문이다. 시간이 지나 종료된 인스턴스가 쌓이면서 확률적으로 실패한다.
///
/// ActivityKit 실인스턴스는 유닛 테스트에서 만들 수 없으므로, **고르는 규칙만** 순수 함수로
/// 떼어내 검증한다(`LiveActivityHandlePicker`). 인텐트·서비스는 이 규칙을 쓰기만 한다.
struct LiveActivityHandlePickingTests {

    /// 테스트용 인스턴스 대역 — 실제 `Activity`의 `activityState`만 흉내낸다.
    private struct Handle: Equatable {
        let id: String
        let state: LiveActivityHandleState
    }

    private func pick(_ handles: [Handle]) -> Handle? {
        LiveActivityHandlePicker.liveOne(from: handles, state: \.state)
    }

    // MARK: - 재현: 죽은 인스턴스를 고르면 안 된다

    /// **재현 핵심.** 종료된 인스턴스가 앞에 있어도 살아있는 것을 골라야 한다.
    /// 지금 코드(`activities.first`)는 앞의 `.ended`를 잡고, 거기 update해봐야 무시된다.
    @Test func picksActiveEvenWhenEndedComesFirst() {
        let handles = [
            Handle(id: "old", state: .ended),
            Handle(id: "live", state: .active),
        ]

        #expect(pick(handles)?.id == "live")
    }

    /// 사용자가 잠금화면에서 치운 인스턴스도 건너뛴다.
    @Test func skipsDismissedHandles() {
        let handles = [
            Handle(id: "swiped-away", state: .dismissed),
            Handle(id: "live", state: .active),
        ]

        #expect(pick(handles)?.id == "live")
    }

    /// `.stale`은 **살아있다** — 화면에 떠 있고 update로 되살릴 수 있다.
    /// 이걸 건너뛰면 오래된 카드를 영영 갱신하지 못한다.
    @Test func staleHandleIsStillUsable() {
        let handles = [Handle(id: "stale-but-visible", state: .stale)]

        #expect(pick(handles)?.id == "stale-but-visible")
    }

    /// 전부 죽었으면 nil — 아무것도 하지 않는 게 맞다(엉뚱한 데 update 금지).
    @Test func returnsNilWhenAllHandlesAreDead() {
        let handles = [
            Handle(id: "a", state: .ended),
            Handle(id: "b", state: .dismissed),
        ]

        #expect(pick(handles) == nil)
    }

    /// 살아있는 게 여럿이면 첫 번째 — 갱신(update)할 대상은 하나면 된다.
    /// 나머지 중복은 `liveAll`로 걷어낸다(아래 "종류당 1개" 테스트).
    @Test func picksFirstAmongMultipleLiveHandles() {
        let handles = [
            Handle(id: "first", state: .active),
            Handle(id: "second", state: .active),
        ]

        #expect(pick(handles)?.id == "first")
    }

    /// 빈 목록 — 앱이 백그라운드에서 막 깨어나 아직 안 채워진 경우.
    @Test func returnsNilForEmptyList() {
        #expect(pick([]) == nil)
    }

    // MARK: - 종류당 1개: 살아있는 것 전부

    /// 증상(2026-09-20 보고): 앱을 열었다 닫을 때마다 일정 카드가 쌓여 최대 4개, 단축어
    /// 「라이브 새로고침」을 돌려도 옛 카드가 남는다.
    ///
    /// 원인 — 게시 경로가 **보관 핸들 1개**만 끝내고 새로 요청한다. 어떤 이유로든 같은
    /// 종류가 2개가 되는 순간(런치 직후 `activities`가 잠깐 비는 ActivityKit 특성 등)
    /// 1개만 교체되고 나머지는 영구히 남아 자가 복구가 안 된다.
    ///
    /// 규칙 — 게시·종료 전에 **살아있는 같은 종류를 전부** 골라 끝낸다. 죽은 것은 제외
    /// (end 호출은 무해하지만 의미가 없다), 순서는 시스템 컬렉션 그대로 보존한다.
    private func pickAll(_ handles: [Handle]) -> [Handle] {
        LiveActivityHandlePicker.liveAll(from: handles, state: \.state)
    }

    /// **재현 핵심.** 살아있는 게 여럿이면 전부 돌려준다 — 하나만 끝내면 나머지가 남는다.
    @Test func liveAllReturnsEveryLiveHandle() {
        let handles = [
            Handle(id: "first", state: .active),
            Handle(id: "second", state: .active),
            Handle(id: "third", state: .stale),
        ]

        #expect(pickAll(handles).map(\.id) == ["first", "second", "third"])
    }

    /// 죽은 것은 섞여 있어도 빠진다.
    @Test func liveAllSkipsDeadHandles() {
        let handles = [
            Handle(id: "ended", state: .ended),
            Handle(id: "live", state: .active),
            Handle(id: "gone", state: .dismissed),
        ]

        #expect(pickAll(handles).map(\.id) == ["live"])
    }

    /// 전부 죽었거나 비었으면 빈 배열.
    @Test func liveAllIsEmptyWhenNothingLive() {
        #expect(pickAll([Handle(id: "a", state: .ended)]).isEmpty)
        #expect(pickAll([]).isEmpty)
    }
}
