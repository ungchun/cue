//
//  LiveActivityContentStateTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 메모·일정 LA ContentState의 전방 호환 디코딩 — 앱 업데이트 전 게시된 활성 LA를
/// 재포착(sync)할 때 새 필드(`calendarMonthOffset` 등)가 없어도 깨지지 않아야 한다.
struct LiveActivityContentStateTests {

    // MARK: - 메모 ContentState

    /// `calendarMonthOffset` 키가 없는 옛 상태는 0(이번 달)으로 채워 디코딩된다.
    @Test func memoStateDecodesLegacyWithoutCalendarOffset() throws {
        let legacy = Data(##"{"text":"메모","colorHex":"#123456"}"##.utf8)

        let state = try JSONDecoder().decode(MemoLiveActivityAttributes.ContentState.self, from: legacy)

        #expect(state.text == "메모")
        #expect(state.textColorHex == "#FFFFFF")   // 기존 전방 호환 유지
        #expect(state.calendarMonthOffset == 0)
    }

    /// 오프셋이 인코딩·디코딩 왕복에서 보존된다 — 월 이동 상태가 update를 넘어 살아남는다.
    @Test func memoStateRoundTripsCalendarOffset() throws {
        var state = MemoLiveActivityAttributes.ContentState(text: "메모", colorHex: "#123456")
        state.calendarMonthOffset = -3

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(MemoLiveActivityAttributes.ContentState.self, from: data)

        #expect(decoded.calendarMonthOffset == -3)
    }

    // MARK: - 일정 ContentState

    /// `todayCount`·`calendarMonthOffset` 키가 없는 옛 상태도 기본값으로 채워 디코딩된다.
    @Test func scheduleStateDecodesLegacyWithoutNewKeys() throws {
        let legacy = Data(##"{"days":[]}"##.utf8)

        let state = try JSONDecoder().decode(ScheduleLiveActivityAttributes.ContentState.self, from: legacy)

        #expect(state.days.isEmpty)
        #expect(state.todayCount == 0)
        #expect(state.calendarMonthOffset == 0)
    }

    /// 오프셋이 인코딩·디코딩 왕복에서 보존된다.
    @Test func scheduleStateRoundTripsCalendarOffset() throws {
        var state = ScheduleLiveActivityAttributes.ContentState(days: [], todayCount: 2)
        state.calendarMonthOffset = 5

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ScheduleLiveActivityAttributes.ContentState.self, from: data)

        #expect(decoded.todayCount == 2)
        #expect(decoded.calendarMonthOffset == 5)
    }
}
