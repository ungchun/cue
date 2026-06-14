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

    /// 집중 세션의 단계 종료 알림 스케줄러. ViewModel이 schedule/cancel을 직접 호출한다.
    var focusNotifications: any FocusNotificationScheduling
    /// 세션 동안 백그라운드 오디오로 앱을 깨어 있게 유지 — 잠금/백그라운드에서도 단계 전환·
    /// LA 갱신이 작동하게 한다. 세션 시작/복원에 start, 종료/완료에 stop.
    var focusAudioKeepAlive: any BackgroundAudioKeeping

    /// 저장된 세션 프리셋 영속화 — onAppear 시 fetch, CRUD 직후 save.
    var fetchFocusSessions: FetchFocusSessionsUseCase
    var saveFocusSessions: SaveFocusSessionsUseCase

    /// 마지막으로 선택된 세션 id 영속화 — 앱 재시작 후에도 같은 세션을 메인 화면에 띄운다.
    var fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase
    var saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase

    /// 진행 중 세션 스냅샷 영속화 — 앱 강제 종료 후 재실행에도 타이머를 복원한다.
    var fetchActiveFocusSession: FetchActiveFocusSessionUseCase
    var saveActiveFocusSession: SaveActiveFocusSessionUseCase

    // MARK: - Live Activity

    /// 라이브 액티비티 트리거 — Focus는 자동(세션 시작/페이즈 전환), Reminder/Schedule은 사용자가
    /// 동그라미 버튼으로 토글. 구체 service는 `CompositionRoot`에서 `ActivityKitLiveActivityService`,
    /// preview는 `DisabledLiveActivityService`(no-op).
    var startFocusLiveActivity: StartFocusLiveActivityUseCase
    var updateFocusLiveActivity: UpdateFocusLiveActivityUseCase
    var endFocusLiveActivity: EndFocusLiveActivityUseCase
    /// 앱 재실행 시 진행 중 세션의 LA 복원 — 기존 인스턴스 채택 또는 새로 시작.
    var restoreFocusLiveActivity: RestoreFocusLiveActivityUseCase
    var startReminderLiveActivity: StartReminderLiveActivityUseCase
    var endReminderLiveActivity: EndReminderLiveActivityUseCase
    var startScheduleLiveActivity: StartScheduleLiveActivityUseCase
    var endScheduleLiveActivity: EndScheduleLiveActivityUseCase
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
            focusNotifications: NoopFocusNotificationScheduler(),
            focusAudioKeepAlive: DisabledAudioKeepAliveService(),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            fetchActiveFocusSession: FetchActiveFocusSessionUseCase(repository: focusSessionsRepository),
            saveActiveFocusSession: SaveActiveFocusSessionUseCase(repository: focusSessionsRepository),
            startFocusLiveActivity: StartFocusLiveActivityUseCase(service: liveActivityService),
            updateFocusLiveActivity: UpdateFocusLiveActivityUseCase(service: liveActivityService),
            endFocusLiveActivity: EndFocusLiveActivityUseCase(service: liveActivityService),
            restoreFocusLiveActivity: RestoreFocusLiveActivityUseCase(service: liveActivityService),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: liveActivityService),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: liveActivityService),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: liveActivityService),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: liveActivityService),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: liveActivityService)
        )
    }
}
