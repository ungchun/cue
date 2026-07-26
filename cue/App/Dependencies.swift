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
    /// 전체 탭 섹션 간 드래그 — 항목을 다른 리스트로 이동. 기본값은 인메모리 no-op 수준 —
    /// 실 배선은 `CompositionRoot`·테스트 헬퍼에서 같은 repo 인스턴스로 교체.
    var moveReminder: MoveReminderUseCase = .init(repository: InMemoryRemindersRepository())
    var addReminderList: AddReminderListUseCase
    var updateReminderList: UpdateReminderListUseCase
    var deleteReminderList: DeleteReminderListUseCase
    /// 외부(미리 알림 앱)에서 변경 발생 시 신호 — ViewModel은 onAppear에 한 번 구독하고
    /// 신호가 올 때마다 reload. 매 화면 진입에 reload하던 동작을 대체한다.
    var observeRemindersChanges: ObserveRemindersChangesUseCase

    /// 섹션(오늘·개별 리스트)별 정렬 설정 + 수동 순서 영속화. EventKit이 제공하지 않아
    /// 앱이 로컬에 따로 보관 — 선택 변경/드래그 직후 save, 스코프 진입 시 fetch.
    var fetchReminderSortSettings: FetchReminderSortSettingsUseCase
    var saveReminderSortSettings: SaveReminderSortSettingsUseCase

    var requestEventsAccess: RequestEventsAccessUseCase
    var fetchEvents: FetchEventsUseCase
    /// 사용자 캘린더 목록 — 설정 "볼 캘린더 선택" 체크리스트가 읽는다.
    var fetchCalendars: FetchCalendarsUseCase
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

    /// 온보딩 첫 큐 게시에 곁들이는 예시 일정·할일 LA — 권한·실데이터·쿼터 없이 3카드 장면.
    var startSampleLiveActivities: StartSampleLiveActivitiesUseCase
    /// 예시 LA 정리 — 포그라운드 복귀 시(온보딩 커버 없을 때) 마커 기반으로 예시만 종료.
    var endSampleLiveActivities: EndSampleLiveActivitiesUseCase

    /// 단일 메모 영속화 — onAppear 시 fetch, 텍스트·색 변경 직후 save.
    var fetchMemo: FetchMemoUseCase
    var saveMemo: SaveMemoUseCase
    /// 메모 라이브 액티비티 트리거 — 사용자가 동그라미 버튼으로 토글. 큰 텍스트 카드.
    var startMemoLiveActivity: StartMemoLiveActivityUseCase
    var endMemoLiveActivity: EndMemoLiveActivityUseCase

    /// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 service가 재포착.
    var syncLiveActivities: SyncLiveActivitiesUseCase

    /// 설정 변경 직후 호출 — 켜져 있는 LA를 재게시해 렌더 시점 설정(캘린더 표시)을 즉시 반영.
    var refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase

    /// 무료 사용자의 라이브 활성화(켜기·새로고침) 하루 한도 소비 — 켜기 버튼에서 호출.
    var consumeLiveActivation: ConsumeLiveActivationUseCase

    /// 앱 시작 시 호출 — 원격 최소 버전과 비교해 강제 업데이트 블로커 표시 여부 판정.
    var checkForcedUpdate: CheckForcedUpdateUseCase

    /// 기존 설치 흔적 감지 — 온보딩 도입 업데이트에서 기존 사용자에게 온보딩을 건너뛰기 위함.
    /// 기본값은 "흔적 없음"(프리뷰 = 신규 설치 취급) — 실 배선은 `CompositionRoot`에서.
    var detectPriorInstall: DetectPriorInstallUseCase =
        .init(repository: InMemoryPriorInstallRepository())

    // MARK: - 앱 전역 설정

    /// 앱 전역 설정(화면 모드 등) 영속화 — 설정 탭 진입 시 fetch, 항목 변경 직후 save.
    /// 각 기능 ViewModel도 자기 화면 진입 시 fetch로 관련 설정을 읽는다.
    var fetchAppSettings: FetchAppSettingsUseCase
    var saveAppSettings: SaveAppSettingsUseCase

    // MARK: - 앱 시작 프리페치 + 첫 페인트 스냅샷 캐시

    /// 프롬프트 없는 권한 상태 조회 — 앱 시작 프리페치가 "이미 허용된 경우에만" 돌기 위한 경로.
    /// 기본값은 인메모리 no-op 수준 — 실 배선은 `CompositionRoot`에서 같은 repo 인스턴스로 교체.
    var currentRemindersAccess: CurrentRemindersAccessUseCase =
        .init(repository: InMemoryRemindersRepository(access: .notDetermined))
    var currentEventsAccess: CurrentEventsAccessUseCase =
        .init(repository: InMemoryEventsRepository(access: .notDetermined))

    /// 마지막 fetch 결과 스냅샷 — 앱 재시작 시 스피너 없이 즉시 첫 페인트하기 위한 캐시.
    /// 기본값은 빈 인메모리(복원 nil = 기존 스피너 경로) — 실 배선은 `CompositionRoot`에서.
    var loadRemindersSnapshot: LoadRemindersSnapshotUseCase =
        .init(repository: InMemorySnapshotCacheRepository())
    var saveRemindersSnapshot: SaveRemindersSnapshotUseCase =
        .init(repository: InMemorySnapshotCacheRepository())
    var loadEventsSnapshot: LoadEventsSnapshotUseCase =
        .init(repository: InMemorySnapshotCacheRepository())
    var saveEventsSnapshot: SaveEventsSnapshotUseCase =
        .init(repository: InMemorySnapshotCacheRepository())

    /// 분석 이벤트 기록 — 프로덕션은 Firebase(GA4), 프리뷰·테스트는 no-op.
    /// fire-and-forget이라 UseCase 없이 서비스 경계를 그대로 노출한다.
    var analytics: any AnalyticsService = DisabledAnalyticsService()

    /// 앱 시작 시 강등(비프리미엄) 사용자의 프리미엄 전용 설정 잔존값을 정리한다.
    /// 기본값은 인메모리 no-op — 프리뷰·테스트 조립이 실 저장소 없이 동작한다.
    var reconcilePremiumSettings: ReconcilePremiumSettingsUseCase = {
        let repository = InMemoryAppSettingsRepository()
        let memoRepository = InMemoryMemoRepository()
        return ReconcilePremiumSettingsUseCase(
            fetch: FetchAppSettingsUseCase(repository: repository),
            save: SaveAppSettingsUseCase(repository: repository),
            fetchMemo: FetchMemoUseCase(repository: memoRepository),
            saveMemo: SaveMemoUseCase(repository: memoRepository)
        )
    }()
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
            ],
            calendars: [
                EventCalendar(id: "cal-personal", title: "개인", colorHex: "#0A84FF"),
                EventCalendar(id: "cal-work", title: "회사", colorHex: "#34C759"),
                EventCalendar(id: "cal-holidays", title: "대한민국 공휴일", colorHex: "#FF3B30"),
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
        let reminderSortRepository = InMemoryReminderSortRepository()
        let appSettingsRepository = InMemoryAppSettingsRepository()
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
            fetchReminderSortSettings: FetchReminderSortSettingsUseCase(repository: reminderSortRepository),
            saveReminderSortSettings: SaveReminderSortSettingsUseCase(repository: reminderSortRepository),
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository),
            fetchCalendars: FetchCalendarsUseCase(repository: eventsRepository),
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepository),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: liveActivityService),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: liveActivityService),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: liveActivityService),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: liveActivityService),
            startSampleLiveActivities: StartSampleLiveActivitiesUseCase(
                startSchedule: StartScheduleLiveActivityUseCase(service: liveActivityService),
                startReminder: StartReminderLiveActivityUseCase(service: liveActivityService)
            ),
            endSampleLiveActivities: EndSampleLiveActivitiesUseCase(service: liveActivityService),
            fetchMemo: FetchMemoUseCase(repository: memoRepository),
            saveMemo: SaveMemoUseCase(repository: memoRepository),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: liveActivityService),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: liveActivityService),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: liveActivityService),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: liveActivityService),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: DisabledAppUpdatePolicyService()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: appSettingsRepository),
            saveAppSettings: SaveAppSettingsUseCase(repository: appSettingsRepository)
        )
    }
}
