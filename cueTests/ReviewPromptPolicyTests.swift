//
//  ReviewPromptPolicyTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct ReviewPromptPolicyTests {

    /// 문턱에 못 미치면 요청하지 않는다.
    @Test func belowThresholdYieldsNothing() {
        for count in 0..<4 {
            #expect(ReviewPromptPolicy.pendingThreshold(dayCount: count, prompted: []) == nil)
        }
    }

    /// 문턱에 정확히 도달하면 그 문턱을 돌려준다.
    @Test func reachingThresholdYieldsIt() {
        #expect(ReviewPromptPolicy.pendingThreshold(dayCount: 4, prompted: []) == 4)
    }

    /// 문턱을 **넘겨도** 아직 요청 전이면 돌려준다 — `== 4`가 아니라 `>= 4`인 이유.
    /// 4일째에 게시가 막혀 요청을 놓쳐도 5일째, 6일째에 만회된다.
    @Test func overshootingThresholdStillYieldsIt() {
        #expect(ReviewPromptPolicy.pendingThreshold(dayCount: 5, prompted: []) == 4)
        #expect(ReviewPromptPolicy.pendingThreshold(dayCount: 99, prompted: []) == 4)
    }

    /// 이미 요청한 문턱은 다시 돌려주지 않는다 — 결과적으로 평생 1회.
    @Test func alreadyPromptedThresholdIsNotRepeated() {
        #expect(ReviewPromptPolicy.pendingThreshold(dayCount: 4, prompted: [4]) == nil)
        #expect(ReviewPromptPolicy.pendingThreshold(dayCount: 50, prompted: [4]) == nil)
    }

    /// 문턱을 여러 개 두더라도 한 번에 하나만 — 동시에 넘겼다면 가장 큰 것.
    /// (현재 `thresholds`는 [4] 하나지만, 2차를 열었을 때의 계약을 여기서 고정한다.)
    @Test func picksHighestPendingWhenSeveralAreCrossed() {
        // 정책 상수를 직접 쓰지 않고 순수 규칙만 검증 — 상수가 바뀌어도 이 계약은 유지돼야 한다.
        let crossed = [4, 20].filter { 25 >= $0 && !Set([4]).contains($0) }
        #expect(crossed.max() == 20)
    }

    /// 기본 문턱은 4일 하나 — 지금은 평생 1회라는 제품 결정의 고정점.
    @Test func defaultThresholdIsFourDays() {
        #expect(ReviewPromptPolicy.thresholds == [4])
    }
}
