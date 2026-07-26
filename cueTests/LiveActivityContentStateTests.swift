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

    // MARK: - 크기 한도 (ActivityKit ~4KB)

    /// 일정 ContentState는 worst-case(캘린더 함께 보기 ON: 이벤트 cap + 주간·월간 점 가득)에서도
    /// ActivityKit 4KB 한도 안이어야 한다. 초과하면 `Activity.request`가 throw해 "라이브 시작 불가"
    /// alert가 뜬다. 수정: 이벤트 `id`를 짧은 합성값으로, 캘린더 ON이면 서비스가 예산에 맞게 이벤트 수를
    /// 적응적으로 줄인다(안 들어가면 사다리로 축소). 이 테스트는 대표 heavy 상태가 4KB 안임을 고정.
    @Test func scheduleContentStateStaysUnderSizeLimit() throws {
        // 서비스가 예산 안에서 낮춘 대표값(6 이벤트) + 짧은 id.
        let cap = 6
        let events = (0..<cap).map { i in
            LiveEventItem(
                id: "\(i)",
                title: "프로젝트 회의 및 주간 리뷰 \(i)",
                startDate: Date(timeIntervalSince1970: 1_784_000_000 + Double(i) * 3600),
                endDate: Date(timeIntervalSince1970: 1_784_003_600 + Double(i) * 3600),
                timeText: "오전 9:00 - 오전 10:00",
                calendarColorHex: "#FF3B30",
                isAllDay: false
            )
        }
        let days = stride(from: 0, to: events.count, by: 3).map { start in
            LiveScheduleDay(
                id: "2026-07-\(20 + start)",
                label: "7/\(20 + start) (월)",
                events: Array(events[start..<min(start + 3, events.count)])
            )
        }
        let weekDots = (0..<7).map { i in
            LiveDayEventDots(dayStart: Date(timeIntervalSince1970: 1_784_000_000 + Double(i) * 86_400), colorHexes: ["#FF3B30", "#34C759"])
        }
        let monthDots = (1...31).map { LiveMonthDot(day: $0, colorHexes: ["#FF3B30", "#34C759"]) }

        var state = ScheduleLiveActivityAttributes.ContentState(days: days, todayCount: 14, weekEventDots: weekDots)
        state.monthEventDots = monthDots

        let size = try JSONEncoder().encode(state).count
        #expect(size < 4096, "일정 ContentState가 \(size) 바이트로 4KB 한도를 넘음")
    }

    /// 할일 ContentState도 캘린더 ON worst-case(아이템 cap + 주간·월간 점)에서 4KB 안이어야 한다.
    /// 할일 아이템 id는 EventKit 식별자(긴 문자열)라 못 줄이므로 캘린더 ON이면 아이템 수를 제한한다.
    @Test func reminderContentStateStaysUnderSizeLimit() throws {
        let longID = "x-apple-reminderkit://REMCDReminder/8A9B0C1D-2E3F-4A5B-6C7D-8E9F0A1B2C3D"
        // 서비스가 예산 안에서 낮춘 대표값(6 아이템).
        let items = (0..<6).map { i in
            LiveReminderItem(id: "\(longID)-\(i)", title: "장보기 목록 정리 및 확인 \(i)", colorHex: "#FF3B30")
        }
        let weekDots = (0..<7).map { i in
            LiveDayEventDots(dayStart: Date(timeIntervalSince1970: 1_784_000_000 + Double(i) * 86_400), colorHexes: ["#FF3B30", "#34C759"])
        }
        let monthDots = (1...31).map { LiveMonthDot(day: $0, colorHexes: ["#FF3B30", "#34C759"]) }

        var state = ReminderLiveActivityAttributes.ContentState(items: items, remaining: 30, todayCount: 30, weekEventDots: weekDots)
        state.monthEventDots = monthDots

        let size = try JSONEncoder().encode(state).count
        #expect(size < 4096, "할일 ContentState가 \(size) 바이트로 4KB 한도를 넘음")
    }

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

    /// `showsCalendarOverride` 키가 없는 옛 상태는 nil로 디코딩 — 위젯이 설정 미러를 따르는 기존 동작 유지.
    @Test func scheduleStateDecodesLegacyWithoutCalendarOverrideAsNil() throws {
        let legacy = Data(##"{"days":[]}"##.utf8)

        let state = try JSONDecoder().decode(ScheduleLiveActivityAttributes.ContentState.self, from: legacy)

        #expect(state.showsCalendarOverride == nil)
    }

    /// 온보딩 목업이 켠 캘린더 오버라이드가 왕복에서 보존된다 — 위젯이 미러 대신 이 값을 따라야 함.
    @Test func scheduleStateRoundTripsCalendarOverride() throws {
        var state = ScheduleLiveActivityAttributes.ContentState(days: [], todayCount: 0)
        state.showsCalendarOverride = true

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ScheduleLiveActivityAttributes.ContentState.self, from: data)

        #expect(decoded.showsCalendarOverride == true)
    }
}
