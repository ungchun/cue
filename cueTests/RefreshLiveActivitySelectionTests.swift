//
//  RefreshLiveActivitySelectionTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 단축어 자동화가 **무엇을** 되살릴지 고르는 규칙 — 할일 범위와 숨김 필터.
///
/// 인텐트는 ViewModel 없이 도는 경로라 화면이 하던 선별을 스스로 해야 한다. 이 규칙이
/// 화면과 어긋나면 잠금화면에 뜨는 목록이 앱에서 보던 것과 달라진다 — 사용자는 그걸
/// "라이브가 이상하다"로 받아들인다.
struct RefreshLiveActivitySelectionTests {

    private let lists = [
        ReminderList(id: "L1", title: "장보기", colorHex: "#FF0000"),
        ReminderList(id: "L2", title: "업무", colorHex: nil),
    ]

    // MARK: - 할일 범위

    /// 설정에 저장된 범위를 그대로 쓴다 — 사용자가 「항상 표시」에서 고른 값이다.
    @Test func reminderScopeFollowsTheSavedSetting() {
        #expect(RefreshLiveActivitySelection.reminderScope(scopeID: "today", lists: lists)
                == .systemFilter(.today))
        #expect(RefreshLiveActivitySelection.reminderScope(scopeID: "L1", lists: lists)
                == .list("L1"))
    }

    /// 저장된 리스트가 **삭제됐으면** 전체로 떨어진다.
    ///
    /// 그대로 두면 빈 목록이 게시되고, 사용자는 할일이 남아 있는데도 빈 라이브를 본다.
    @Test func deletedListFallsBackToAll() {
        #expect(RefreshLiveActivitySelection.reminderScope(scopeID: "GONE", lists: lists)
                == .systemFilter(.all))
    }

    /// 라이브 제목은 범위를 따라간다 — 리스트면 그 이름, 필터면 필터 이름.
    @Test func titleFollowsTheScope() {
        #expect(RefreshLiveActivitySelection.title(for: .list("L1"), lists: lists) == "장보기")
        #expect(RefreshLiveActivitySelection.title(for: .systemFilter(.today), lists: lists)
                == SystemFilter.today.title)
    }

    /// 삭제된 리스트의 제목은 전체로 폴백한다 — 범위 해석과 같은 방향이다.
    @Test func titleOfDeletedListFallsBack() {
        #expect(RefreshLiveActivitySelection.title(for: .list("GONE"), lists: lists)
                == SystemFilter.all.title)
    }

    // MARK: - 숨긴 항목 제외

    /// 숨긴 리스트의 할일은 되살릴 때도 빠진다 — 화면과 같은 기준이다.
    @Test func hiddenReminderListsAreExcluded() {
        let items = [
            makeReminder(id: "1", listID: "L1"),
            makeReminder(id: "2", listID: "L2"),
        ]
        let visible = RefreshLiveActivitySelection.visibleReminders(items, hiddenListIDs: ["L2"])
        #expect(visible.map(\.id) == ["1"])
    }

    /// 완료된 할일은 싣지 않는다 — 라이브는 남은 일을 보여주는 화면이다.
    @Test func completedRemindersAreExcluded() {
        let items = [
            makeReminder(id: "1", listID: "L1", isCompleted: true),
            makeReminder(id: "2", listID: "L1"),
        ]
        let visible = RefreshLiveActivitySelection.visibleReminders(items, hiddenListIDs: [])
        #expect(visible.map(\.id) == ["2"])
    }

    /// 숨긴 캘린더의 일정은 되살릴 때도 빠진다 — 화면과 같은 기준이다.
    @Test func hiddenCalendarEventsAreExcluded() {
        let events = [
            makeEvent(id: "1", calendarID: "C1"),
            makeEvent(id: "2", calendarID: "C2"),
        ]
        let visible = RefreshLiveActivitySelection.visibleEvents(events, hiddenCalendarIDs: ["C2"])
        #expect(visible.map(\.id) == ["1"])
    }

    /// 숨김이 없으면 전부 남는다.
    @Test func nothingHiddenKeepsEverything() {
        let events = [makeEvent(id: "1", calendarID: "C1")]
        #expect(RefreshLiveActivitySelection.visibleEvents(events, hiddenCalendarIDs: []).count == 1)
    }

    // MARK: - 범위별 선별

    /// 리스트 범위는 그 리스트의 할일만 남긴다.
    @Test func listScopeKeepsOnlyThatList() {
        let items = [makeReminder(id: "1", listID: "L1"), makeReminder(id: "2", listID: "L2")]
        let matched = RefreshLiveActivitySelection.matching(items, scope: .list("L1"))
        #expect(matched.map(\.id) == ["1"])
    }

    /// 「오늘」은 지난 마감(overdue)까지 포함한다 — 화면과 같은 기준이다.
    ///
    /// overdue를 빼면 기한이 지난 일이 잠금화면에서 사라져, 가장 급한 것이 안 보인다.
    @Test func todayIncludesOverdue() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            makeReminder(id: "overdue", listID: "L1", due: now.addingTimeInterval(-86_400)),
            makeReminder(id: "today", listID: "L1", due: now.addingTimeInterval(600)),
            makeReminder(id: "nextWeek", listID: "L1", due: now.addingTimeInterval(7 * 86_400)),
            makeReminder(id: "noDue", listID: "L1"),
        ]
        let matched = RefreshLiveActivitySelection.matching(
            items, scope: .systemFilter(.today), now: now
        )
        #expect(Set(matched.map(\.id)) == ["overdue", "today"])
    }

    /// 「예정」은 마감이 있는 것만, 가까운 순으로 — 마감 없는 항목은 빠진다.
    @Test func scheduledKeepsDatedItemsInDueOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            makeReminder(id: "late", listID: "L1", due: now.addingTimeInterval(7 * 86_400)),
            makeReminder(id: "noDue", listID: "L1"),
            makeReminder(id: "soon", listID: "L1", due: now.addingTimeInterval(3600)),
        ]
        let matched = RefreshLiveActivitySelection.matching(
            items, scope: .systemFilter(.scheduled), now: now
        )
        #expect(matched.map(\.id) == ["soon", "late"])
    }

    /// 「전체」는 마감 가까운 순, **마감 없는 것은 맨 뒤**로 보낸다.
    ///
    /// 마감 없는 항목을 앞에 두면 급한 일이 6개 표시 한도 밖으로 밀려난다.
    @Test func allSortsByDueDatePushingUndatedToTheEnd() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let items = [
            makeReminder(id: "noDue", listID: "L1"),
            makeReminder(id: "late", listID: "L1", due: now.addingTimeInterval(7 * 86_400)),
            makeReminder(id: "soon", listID: "L1", due: now.addingTimeInterval(3600)),
        ]
        let matched = RefreshLiveActivitySelection.matching(
            items, scope: .systemFilter(.all), now: now
        )
        #expect(matched.map(\.id) == ["soon", "late", "noDue"])
    }

    // MARK: - 헬퍼

    private func makeReminder(
        id: String, listID: String, isCompleted: Bool = false, due: Date? = nil
    ) -> Reminder {
        Reminder(id: id, title: "항목 \(id)", isCompleted: isCompleted, dueDate: due, listID: listID)
    }

    private func makeEvent(id: String, calendarID: String) -> CalendarEvent {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        return CalendarEvent(
            id: id, title: "일정 \(id)",
            startDate: start, endDate: start.addingTimeInterval(3600),
            isAllDay: false, calendarColorHex: nil, isReadOnly: false, calendarID: calendarID
        )
    }
}
