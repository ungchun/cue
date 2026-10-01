//
//  RefreshLiveActivityDecisionTests.swift
//  cueTests
//

import Testing
@testable import cue

/// 단축어 자동화가 라이브를 게시할 수 있는지 판단하는 규칙.
///
/// 8시간마다 자동으로 도는 경로라 판단이 틀리면 **사용자가 눈치채지 못한 채** 잘못된 상태가
/// 하루 세 번 반복된다. 그래서 결정만 순수 함수로 떼어내 화면 없이 검증한다.
struct RefreshLiveActivityDecisionTests {

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
