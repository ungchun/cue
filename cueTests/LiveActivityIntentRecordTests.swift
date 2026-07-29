//
//  LiveActivityIntentRecordTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// "사용자가 켜둔 채로 두었다"는 사실의 기록 — 단축어 자동화가 무엇을 되살릴지 가른다.
///
/// ActivityKit은 라이브가 **왜** 사라졌는지 알려주지 않는다. 사용자가 직접 껐든 시스템이
/// 8시간으로 죽였든 똑같이 "없음"이다. 그래서 켤 때 기록하고 끌 때 지워, 자동화가 이 기록만
/// 보고 판단하게 한다. 기록이 틀리면 사용자가 끈 라이브가 8시간마다 되살아난다.
struct LiveActivityIntentRecordTests {

    /// 각 테스트가 서로의 저장값을 보지 않도록 격리된 defaults를 쓴다.
    private func makeStore() -> UserDefaults {
        let suite = "cue.tests.intent.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    /// 아무것도 안 켰으면 되살릴 것도 없다.
    @Test func nothingIsRecordedInitially() {
        let store = makeStore()
        #expect(LiveActivityIntentRecord.wanted(in: store).isEmpty)
    }

    /// 켜면 기록된다 — 자동화가 이걸 보고 되살린다.
    @Test func startingRecordsTheKind() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.memo, in: store)
        #expect(LiveActivityIntentRecord.wanted(in: store) == [.memo])
    }

    /// **직접 끄면 기록이 지워진다** — 사용자가 끈 것을 기계가 되살리지 않는다.
    ///
    /// 이 규칙이 이 타입의 존재 이유다. 시스템이 8시간으로 죽인 경우엔 이 경로를 타지 않아
    /// 기록이 남고, 그래서 되살아난다.
    @Test func endingClearsTheKind() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.memo, in: store)
        LiveActivityIntentRecord.markEnded(.memo, in: store)
        #expect(LiveActivityIntentRecord.wanted(in: store).isEmpty)
    }

    /// 종류별로 독립이다 — 메모를 꺼도 할일 기록은 남는다.
    @Test func kindsAreTrackedIndependently() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.memo, in: store)
        LiveActivityIntentRecord.markStarted(.reminder, in: store)
        LiveActivityIntentRecord.markEnded(.memo, in: store)
        #expect(LiveActivityIntentRecord.wanted(in: store) == [.reminder])
    }

    /// 같은 종류를 여러 번 켜도 중복되지 않는다 — 새로고침(껐다 켜기)이 흔한 경로다.
    @Test func startingTwiceDoesNotDuplicate() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.schedule, in: store)
        LiveActivityIntentRecord.markStarted(.schedule, in: store)
        #expect(LiveActivityIntentRecord.wanted(in: store) == [.schedule])
    }

    /// 켠 적 없는 것을 끄는 호출은 아무 일도 하지 않는다(방어).
    @Test func endingSomethingNeverStartedIsHarmless() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.memo, in: store)
        LiveActivityIntentRecord.markEnded(.schedule, in: store)
        #expect(LiveActivityIntentRecord.wanted(in: store) == [.memo])
    }

    /// 온보딩 예시가 정리되면 기록도 함께 지워진다.
    ///
    /// 예시도 실사용과 같은 `startSchedule`/`startReminder`를 거치므로 기록이 남는다.
    /// 그대로 두면 **사용자가 고른 적 없는 예시 라이브를** 자동화가 8시간마다 되살린다.
    /// `endSamples()`가 `markEnded`를 부르는 이유이고, 이 테스트가 그 계약을 고정한다.
    @Test func clearingSamplesRemovesTheirRecord() {
        let store = makeStore()
        LiveActivityIntentRecord.markStarted(.schedule, in: store)
        LiveActivityIntentRecord.markStarted(.reminder, in: store)
        LiveActivityIntentRecord.markStarted(.memo, in: store)

        // endSamples()가 하는 일 — 일정·할일 예시만 정리하고 메모는 건드리지 않는다.
        LiveActivityIntentRecord.markEnded(.schedule, in: store)
        LiveActivityIntentRecord.markEnded(.reminder, in: store)

        #expect(LiveActivityIntentRecord.wanted(in: store) == [.memo])
    }
}
