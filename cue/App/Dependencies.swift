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
    /// 외부(미리 알림 앱)에서 변경 발생 시 신호 — ViewModel은 onAppear에 한 번 구독하고
    /// 신호가 올 때마다 reload. 매 화면 진입에 reload하던 동작을 대체한다.
    var observeRemindersChanges: ObserveRemindersChangesUseCase

    var requestEventsAccess: RequestEventsAccessUseCase
    var fetchEvents: FetchEventsUseCase
    /// 외부(캘린더 앱) 변경 신호 — events 측 대응. 위의 reminders 대응과 같은 패턴.
    var observeEventsChanges: ObserveEventsChangesUseCase

    /// 저장된 세션 프리셋 영속화 — onAppear 시 fetch, CRUD 직후 save.
    var fetchFocusSessions: FetchFocusSessionsUseCase
    var saveFocusSessions: SaveFocusSessionsUseCase

    /// 마지막으로 선택된 세션 id 영속화 — 앱 재시작 후에도 같은 세션을 메인 화면에 띄운다.
    var fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase
    var saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase

    // MARK: - Live Activity

    /// 라이브 액티비티 트리거 — Reminder/Schedule은 사용자가 동그라미 버튼으로 토글. 구체 service는
    /// `CompositionRoot`에서 `ActivityKitLiveActivityService`, preview는 `DisabledLiveActivityService`(no-op).
    /// (집중 LA는 AlarmKit으로 이관 — 여기 없음.)
    var startReminderLiveActivity: StartReminderLiveActivityUseCase
    var endReminderLiveActivity: EndReminderLiveActivityUseCase
    var startScheduleLiveActivity: StartScheduleLiveActivityUseCase
    var endScheduleLiveActivity: EndScheduleLiveActivityUseCase

    /// 단일 메모 영속화 — onAppear 시 fetch, 텍스트·색 변경 직후 save.
    var fetchMemo: FetchMemoUseCase
    var saveMemo: SaveMemoUseCase
    /// 메모 라이브 액티비티 트리거 — 사용자가 동그라미 버튼으로 토글. 큰 텍스트 카드.
    var startMemoLiveActivity: StartMemoLiveActivityUseCase
    var endMemoLiveActivity: EndMemoLiveActivityUseCase

    /// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 service가 재포착.
    var syncLiveActivities: SyncLiveActivitiesUseCase
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
                    isAllDay: false, calendarColorHex: "#0A84FF",
                    isReadOnly: false
                ),
                CalendarEvent(
                    id: "ev2", title: "점심 약속",
                    startDate: today.addingTimeInterval(12 * 60 * 60 + 30 * 60),
                    endDate: today.addingTimeInterval(14 * 60 * 60),
                    isAllDay: false, calendarColorHex: "#34C759",
                    isReadOnly: false
                ),
                CalendarEvent(
                    id: "ev3", title: "치과 예약",
                    startDate: today.addingTimeInterval(2 * 24 * 60 * 60 + 15 * 60 * 60),
                    endDate: today.addingTimeInterval(2 * 24 * 60 * 60 + 16 * 60 * 60),
                    isAllDay: false, calendarColorHex: "#FF3B30",
                    isReadOnly: false
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

        // 프리뷰는 인메모리 — 실제 영속화 동작은 CompositionRoot의 UserDefaults 구현으로.
        let focusSessionsRepository = InMemoryFocusSessionsRepository()
        let memoRepository = InMemoryMemoRepository(memo: Memo(text: "나 오늘 할 수 있다", colorHex: "#FF3B30"))

        // 프리뷰는 no-op service — `isEnabled = false`라 start/update가 모두 즉시 return.
        let liveActivityService: any LiveActivityService = DisabledLiveActivityService()

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
            observeRemindersChanges: ObserveRemindersChangesUseCase(repository: remindersRepository),
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository),
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepository),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: liveActivityService),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: liveActivityService),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: liveActivityService),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: liveActivityService),
            fetchMemo: FetchMemoUseCase(repository: memoRepository),
            saveMemo: SaveMemoUseCase(repository: memoRepository),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: liveActivityService),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: liveActivityService),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: liveActivityService)
        )
    }
}
