//
//  CompositionRoot.swift
//  cue / App
//

import SwiftData

/// 조립 루트(Composition Root) — 구체 구현을 생성해 의존성을 연결하는 **유일한** 장소.
/// Data 계층의 구체 타입(`SwiftData...`)은 오직 여기서만 생성한다.
@MainActor
struct CompositionRoot {
    let modelContainer: ModelContainer
    let dependencies: Dependencies
    /// 프리미엄 엔타이틀먼트의 단일 반응형 소유자 — StoreKit 구현으로 조립. 앱이 시작 시 `start()`.
    let premiumStore: PremiumStore

    init() {
        let container = ModelContainerFactory.make()
        let itemRepository = SwiftDataItemRepository(context: container.mainContext)
        let remindersRepository = EventKitRemindersRepository()
        let eventsRepository = EventKitEventsRepository()
        let focusSessionsRepository = UserDefaultsFocusSessionsRepository()
        let memoRepository = UserDefaultsMemoRepository()
        let reminderSortRepository = UserDefaultsReminderSortRepository()
        let appSettingsRepository = UserDefaultsAppSettingsRepository()
        // 첫 페인트 스냅샷 캐시 — 마지막 fetch 결과를 저장해 앱 재시작 시 스피너 없이 그린다.
        let snapshotCacheRepository = UserDefaultsSnapshotCacheRepository()
        // 라이브 액티비티 service — @MainActor 격리. ActivityKit 호출은 모두 main actor에서.
        let liveActivityService: any LiveActivityService = ActivityKitLiveActivityService()

        let analytics = FirebaseAnalyticsService()
        // 잠금화면 LA 인텐트는 Domain을 모르는 Shared 코드라 브리지로 이벤트를 넘긴다.
        // 인텐트 perform()은 본앱 프로세스에서 돌므로 여기서 주입한 클로저가 실제로 불린다.
        LiveActivityAnalyticsBridge.log = { name, parameters in
            analytics.log(name: name, parameters: parameters)
        }

        self.premiumStore = PremiumStore(service: StoreKitPurchaseService(), analytics: analytics)
        self.modelContainer = container
        self.dependencies = Dependencies(
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
            moveReminder: MoveReminderUseCase(repository: remindersRepository),
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
            // Keychain 저장 — 앱 삭제·재설치로 무료 한도(첫날 2회·이후 1회)를 리셋하는 우회를 막는다.
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: KeychainLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: FirebaseAppUpdatePolicyService()),
            detectPriorInstall: DetectPriorInstallUseCase(repository: UserDefaultsPriorInstallRepository()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: appSettingsRepository),
            saveAppSettings: SaveAppSettingsUseCase(repository: appSettingsRepository),
            // 앱 시작 프리페치용 프롬프트-없는 권한 조회 + 첫 페인트 스냅샷 캐시.
            currentRemindersAccess: CurrentRemindersAccessUseCase(repository: remindersRepository),
            currentEventsAccess: CurrentEventsAccessUseCase(repository: eventsRepository),
            loadRemindersSnapshot: LoadRemindersSnapshotUseCase(repository: snapshotCacheRepository),
            saveRemindersSnapshot: SaveRemindersSnapshotUseCase(repository: snapshotCacheRepository),
            loadEventsSnapshot: LoadEventsSnapshotUseCase(repository: snapshotCacheRepository),
            saveEventsSnapshot: SaveEventsSnapshotUseCase(repository: snapshotCacheRepository),
            analytics: analytics,
            reconcilePremiumSettings: ReconcilePremiumSettingsUseCase(
                fetch: FetchAppSettingsUseCase(repository: appSettingsRepository),
                save: SaveAppSettingsUseCase(repository: appSettingsRepository),
                fetchMemo: FetchMemoUseCase(repository: memoRepository),
                saveMemo: SaveMemoUseCase(repository: memoRepository)
            )
        )
    }
}
