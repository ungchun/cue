//
//  SerialGateTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 비동기 작업을 **한 번에 하나씩** 통과시키는 게이트.
///
/// actor는 `await` 지점에서 재진입된다 — "살아있는 걸 전부 끝내고 → 새로 request"처럼
/// 확인과 행동 사이에 await가 끼는 작업은 actor 안에 있어도 서로 끼어든다.
/// 실제 증상: 콜드런치에 일정 게시가 겹쳐 들어와 각자 request, 카드가 최대 4개
/// (2026-09-30 재보고). 게이트가 작업 전체를 하나의 임계 구역으로 묶는다.
struct SerialGateTests {

    /// 겹쳐 들어온 작업들이 동시에 실행되지 않는다.
    @Test func operationsNeverOverlap() async {
        let gate = SerialGate()
        let probe = OverlapProbe()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    await gate.run {
                        await probe.enter()
                        // 임계 구역 안에서 실제로 양보한다 — 게이트가 없으면 여기서 끼어든다.
                        try? await Task.sleep(for: .milliseconds(5))
                        await probe.leave()
                    }
                }
            }
        }

        #expect(await probe.maxConcurrent == 1)
        #expect(await probe.completed == 5)
    }

    /// 먼저 들어온 순서대로 통과한다 — 게시 순서(표시 순서의 보조 기준)가 뒤집히지 않게.
    @Test func waitersRunInArrivalOrder() async {
        let gate = SerialGate()
        let log = OrderLog()

        // 첫 작업이 게이트를 쥔 채 멈춰 있는 동안 나머지를 순서대로 줄 세운다.
        let blocker = Task {
            await gate.run {
                await log.append(0)
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
        while await log.values.isEmpty { await Task.yield() }

        var followers: [Task<Void, Never>] = []
        for index in 1...3 {
            followers.append(Task { await gate.run { await log.append(index) } })
            // 다음 작업을 보내기 전에 이 작업이 대기열에 들어설 틈을 준다.
            try? await Task.sleep(for: .milliseconds(3))
        }

        await blocker.value
        for follower in followers { await follower.value }

        #expect(await log.values == [0, 1, 2, 3])
    }

    /// 작업이 throw해도 게이트는 풀린다 — 한 번의 게시 실패가 이후 게시를 영영 막으면 안 된다.
    @Test func releasesAfterThrow() async {
        let gate = SerialGate()

        await #expect(throws: GateTestError.self) {
            try await gate.run { throw GateTestError() }
        }
        let value = await gate.run { 7 }

        #expect(value == 7)
    }
}

private struct GateTestError: Error {}

/// 임계 구역에 동시에 들어와 있던 최대 개수를 잰다.
private actor OverlapProbe {
    private var current = 0
    private(set) var maxConcurrent = 0
    private(set) var completed = 0

    func enter() {
        current += 1
        maxConcurrent = max(maxConcurrent, current)
    }

    func leave() {
        current -= 1
        completed += 1
    }
}

private actor OrderLog {
    private(set) var values: [Int] = []
    func append(_ value: Int) { values.append(value) }
}
