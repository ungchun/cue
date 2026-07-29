//
//  RefreshLiveActivitySelection.swift
//  cue / Shared
//

import Foundation

/// 단축어 자동화가 **무엇을** 되살릴지 고르는 규칙 — 할일 범위와 숨김 필터.
///
/// 인텐트는 ViewModel 없이 도는 경로라, 화면이 하던 선별을 스스로 해야 한다. 그 규칙을
/// 인텐트 안에 흩어 두면 화면 쪽 규칙이 바뀔 때 한쪽만 고쳐져 **잠금화면과 앱이 다른 목록을
/// 보여주는** 상태가 된다. 그래서 순수 함수로 모아 두고 화면 없이 검증한다.
enum RefreshLiveActivitySelection {

    /// 설정에 저장된 할일 범위를 선택으로 해석한다.
    ///
    /// 저장된 리스트가 삭제됐으면 전체로 떨어진다 — 그대로 두면 빈 목록이 게시되어,
    /// 할일이 남아 있는데도 사용자는 빈 라이브를 본다.
    static func reminderScope(scopeID: String, lists: [ReminderList]) -> ReminderSelection {
        ReminderSelection.resolve(scopeID: scopeID, lists: lists, fallback: .systemFilter(.all))
    }

    /// 라이브에 실을 할일 — 완료된 것과 숨긴 리스트의 것을 뺀다.
    ///
    /// 화면(`ReminderViewModel.snapshot`)과 같은 기준이다. 정렬은 여기서 하지 않는다 —
    /// 사용자 정렬 설정은 화면의 관심사고, 자동화 경로에선 범위별 기본 순서로 충분하다.
    static func visibleReminders(_ reminders: [Reminder], hiddenListIDs: Set<String>) -> [Reminder] {
        reminders.filter { !$0.isCompleted && !hiddenListIDs.contains($0.listID) }
    }

    /// 라이브에 실을 일정 — 숨긴 캘린더의 것을 뺀다(화면과 같은 기준).
    static func visibleEvents(_ events: [CalendarEvent], hiddenCalendarIDs: Set<String>) -> [CalendarEvent] {
        hiddenCalendarIDs.isEmpty
            ? events
            : events.filter { !hiddenCalendarIDs.contains($0.calendarID) }
    }

    /// 범위에 해당하는 할일만 남긴다 — 화면의 시스템 필터와 같은 기준.
    ///
    /// `now`를 주입받는 이유는 "오늘"의 경계가 시각에 의존하기 때문이다(테스트 고정용).
    static func matching(
        _ reminders: [Reminder],
        scope: ReminderSelection,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Reminder] {
        switch scope {
        case .list(let id):
            return reminders.filter { $0.listID == id }
        case .systemFilter(.today):
            // 오늘 자정(다음날 0시) 이전 마감 — overdue + 오늘 마감. 화면과 동일.
            let tomorrow = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
            return reminders.filter { ($0.dueDate.map { $0 < tomorrow }) ?? false }
        case .systemFilter(.scheduled):
            return reminders
                .filter { $0.dueDate != nil }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .systemFilter(.all):
            // 마감 가까운 순, 마감 없음은 뒤로 — 화면의 전체 필터가 LA에 쓰는 순서와 같다.
            return reminders.sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
        }
    }

    /// 범위에 맞는 라이브 제목 — 리스트면 그 이름, 시스템 필터면 필터 이름.
    static func title(for scope: ReminderSelection, lists: [ReminderList]) -> String {
        switch scope {
        case .list(let id):
            return lists.first { $0.id == id }?.title ?? SystemFilter.all.title
        case .systemFilter(let filter):
            return filter.title
        }
    }
}
