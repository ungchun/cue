//
//  RefreshLiveActivityDecisionTests.swift
//  cueTests
//

import Testing
@testable import cue

/// 단축어 자동화가 라이브를 되살릴지 말지 판단하는 규칙.
///
/// 8시간마다 자동으로 도는 경로라 판단이 틀리면 **사용자가 눈치채지 못한 채** 잘못된 상태가
/// 하루 세 번 반복된다. 무료 사용자에게 무제한 게시를 열어주거나, 반대로 사용자가 끈 라이브가
/// 계속 되살아나는 식이다. 그래서 결정만 순수 함수로 떼어내 화면 없이 검증한다.
struct RefreshLiveActivityDecisionTests {

    /// 켜둔 채로 둔 라이브는 되살린다 — 이 기능의 존재 이유 그 자체다.
    @Test func republishesWhatTheUserLeftOn() {
        #expect(RefreshLiveActivityDecision.shouldRepublish(
            isPremium: true, kind: .memo, wanted: [.memo]
        ))
    }

    /// **사용자가 직접 끈 것은 되살리지 않는다.**
    ///
    /// 끄는 순간 기록에서 빠지므로 여기서 걸린다. 이게 없으면 사용자가 끈 라이브가
    /// 8시간마다 살아나 "꺼지지 않는 알림"이 된다.
    @Test func doesNotRepublishWhatTheUserTurnedOff() {
        #expect(!RefreshLiveActivityDecision.shouldRepublish(
            isPremium: true, kind: .memo, wanted: []
        ))
    }

    /// 무료 사용자는 되살리지 않는다 — 「24시간 사용하기」는 프리미엄 기능이다.
    ///
    /// 여기서 막지 않으면 자동화가 하루 한 번 한도를 우회하는 뒷문이 된다.
    @Test func freeUserNeverRepublishes() {
        #expect(!RefreshLiveActivityDecision.shouldRepublish(
            isPremium: false, kind: .memo, wanted: [.memo]
        ))
    }

    /// 종류별로 독립 판단한다 — 메모만 켜뒀으면 일정은 되살리지 않는다.
    @Test func eachKindIsJudgedOnItsOwn() {
        let wanted: Set<LiveActivityKind> = [.memo]
        #expect(RefreshLiveActivityDecision.shouldRepublish(isPremium: true, kind: .memo, wanted: wanted))
        #expect(!RefreshLiveActivityDecision.shouldRepublish(isPremium: true, kind: .schedule, wanted: wanted))
        #expect(!RefreshLiveActivityDecision.shouldRepublish(isPremium: true, kind: .reminder, wanted: wanted))
    }

    // MARK: - 메모 게시 가능 여부

    /// 내용이 있으면 게시한다.
    @Test func memoWithTextCanBePublished() {
        #expect(RefreshLiveActivityDecision.canPublishMemo(
            Memo(text: "회의 준비", colorHex: "#000000")
        ))
    }

    /// 빈 메모는 게시하지 않는다 — 빈 신호는 의미가 없다.
    ///
    /// use case가 어차피 throw하지만, 자동 경로에선 그 실패가 조용히 삼켜져
    /// 사용자에겐 "단축어가 안 먹는다"로만 보인다. 그래서 시도 전에 막는다.
    @Test func emptyMemoCannotBePublished() {
        #expect(!RefreshLiveActivityDecision.canPublishMemo(
            Memo(text: "", colorHex: "#000000")
        ))
        // 공백·줄바꿈만 있는 경우도 빈 것으로 본다.
        #expect(!RefreshLiveActivityDecision.canPublishMemo(
            Memo(text: "   \n ", colorHex: "#000000")
        ))
    }
}
