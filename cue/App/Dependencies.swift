//
//  Dependencies.swift
//  cue / App
//

import SwiftUI

/// 앱 전역 의존성 묶음. `CompositionRoot`에서 조립되어 `@Environment`로 주입된다.
/// View / ViewModel은 이 묶음을 통해 UseCase에만 접근한다.
struct Dependencies: Sendable {
    var fetchItems: FetchItemsUseCase
    var addItem: AddItemUseCase
    var deleteItem: DeleteItemUseCase

    var requestRemindersAccess: RequestRemindersAccessUseCase
    var fetchReminderLists: FetchReminderListsUseCase
    var fetchReminders: FetchRemindersUseCase
    var toggleReminderCompletion: ToggleReminderCompletionUseCase
    var addReminder: AddReminderUseCase
    var updateReminder: UpdateReminderUseCase
    var deleteReminder: DeleteReminderUseCase
    var addReminderList: AddReminderListUseCase
    var updateReminderList: UpdateReminderListUseCase
    var deleteReminderList: DeleteReminderListUseCase

    var requestEventsAccess: RequestEventsAccessUseCase
    var fetchEvents: FetchEventsUseCase
}

extension EnvironmentValues {
    /// 기본값은 인메모리 구현 — Xcode Preview가 `CompositionRoot` 없이도 동작한다.
    @Entry var dependencies: Dependencies = .preview
}

extension Dependencies {
    /// 프리뷰·테스트용 인메모리 의존성.
    static var preview: Dependencies {
        let itemRepository = InMemoryItemRepository(seed: [
            Item(title: "예시 항목", note: "InMemoryItemRepository 제공"),
        ])

        // 프리뷰용 캘린더 이벤트 시드 — 오늘 + 다음 며칠치를 가볍게.
        let today = Calendar.current.startOfDay(for: Date())
        let eventsRepository = InMemoryEventsRepository(
            access: .granted,
            events: [
                CalendarEvent(
                    id: "ev1", title: "팀 회의",
                    startDate: today.addingTimeInterval(10 * 60 * 60),
                    endDate: today.addingTimeInterval(11 * 60 * 60),
                    isAllDay: false, calendarColorHex: "#0A84FF"
                ),
                CalendarEvent(
                    id: "ev2", title: "점심 약속",
                    startDate: today.addingTimeInterval(12 * 60 * 60 + 30 * 60),
                    endDate: today.addingTimeInterval(14 * 60 * 60),
                    isAllDay: false, calendarColorHex: "#34C759"
                ),
                CalendarEvent(
                    id: "ev3", title: "치과 예약",
                    startDate: today.addingTimeInterval(2 * 24 * 60 * 60 + 15 * 60 * 60),
                    endDate: today.addingTimeInterval(2 * 24 * 60 * 60 + 16 * 60 * 60),
                    isAllDay: false, calendarColorHex: "#FF3B30"
                ),
            ]
        )

        let workListID = "preview-work"
        let personalListID = "preview-personal"
        let remindersRepository = InMemoryRemindersRepository(
            access: .granted,
            lists: [
                // 프리뷰용 색 — 실 EventKit 색 대신 iOS 미리알림 기본 팔레트와 비슷한 값.
                ReminderList(id: workListID, title: "회사", colorHex: "#FF9500"),
                ReminderList(id: personalListID, title: "개인", colorHex: "#34C759"),
            ],
            reminders: [
                Reminder(id: "p1", title: "주간 보고서 작성", isCompleted: false,
                         notes: nil, dueDate: nil, listID: workListID),
                Reminder(id: "p2", title: "회의실 예약", isCompleted: true,
                         notes: nil, dueDate: nil, listID: workListID),
                Reminder(id: "p3", title: "장보기", isCompleted: false,
                         notes: nil, dueDate: nil, listID: personalListID),
            ]
        )

        return Dependencies(
            fetchItems: FetchItemsUseCase(repository: itemRepository),
            addItem: AddItemUseCase(repository: itemRepository),
            deleteItem: DeleteItemUseCase(repository: itemRepository),
            requestRemindersAccess: RequestRemindersAccessUseCase(repository: remindersRepository),
            fetchReminderLists: FetchReminderListsUseCase(repository: remindersRepository),
            fetchReminders: FetchRemindersUseCase(repository: remindersRepository),
            toggleReminderCompletion: ToggleReminderCompletionUseCase(repository: remindersRepository),
            addReminder: AddReminderUseCase(repository: remindersRepository),
            updateReminder: UpdateReminderUseCase(repository: remindersRepository),
            deleteReminder: DeleteReminderUseCase(repository: remindersRepository),
            addReminderList: AddReminderListUseCase(repository: remindersRepository),
            updateReminderList: UpdateReminderListUseCase(repository: remindersRepository),
            deleteReminderList: DeleteReminderListUseCase(repository: remindersRepository),
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository)
        )
    }
}
