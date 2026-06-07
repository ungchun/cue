//
//  FocusLiveActivityActionQueueTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// Widget extension(App Intent)이 enqueue한 사용자 액션을 메인 앱이 다음 active 시점에
/// drain하는 통로의 단위 테스트. UserDefaults(suiteName:) 격리로 process 공유는 시뮬레이트
/// 하지 않고 직렬화·순서·소비 의미만 검증한다.
struct FocusLiveActivityActionQueueTests {

    @Test func enqueueThenDrainReturnsActionsInOrder() {
        let queue = FocusLiveActivityActionQueue(defaults: makeIsolatedDefaults())

        queue.enqueue(.pause)
        queue.enqueue(.resume)
        queue.enqueue(.end)

        #expect(queue.drain() == [.pause, .resume, .end])
    }

    @Test func drainOnEmptyQueueReturnsEmpty() {
        let queue = FocusLiveActivityActionQueue(defaults: makeIsolatedDefaults())

        #expect(queue.drain() == [])
    }

    @Test func drainConsumesQueueSoNextDrainIsEmpty() {
        let queue = FocusLiveActivityActionQueue(defaults: makeIsolatedDefaults())

        queue.enqueue(.pause)
        _ = queue.drain()

        #expect(queue.drain() == [])
    }

    @Test func enqueueAfterDrainStartsFreshQueue() {
        let queue = FocusLiveActivityActionQueue(defaults: makeIsolatedDefaults())

        queue.enqueue(.pause)
        _ = queue.drain()
        queue.enqueue(.end)

        #expect(queue.drain() == [.end])
    }

    // MARK: - 헬퍼

    /// 각 테스트마다 격리된 UserDefaults — 실제 App Group suite는 process 간 공유라
    /// 테스트가 서로 데이터를 보지 않도록 매번 새 suiteName(UUID).
    private func makeIsolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "test-" + UUID().uuidString) ?? .standard
    }
}
