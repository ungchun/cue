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
        // 라이브 액티비티 service — @MainActor 격리. ActivityKit 호출은 모두 main actor에서.
        let liveActivityService: any LiveActivityService = ActivityKitLiveActivityService()

        self.premiumStore = PremiumStore(service: StoreKitPurchaseService())
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
            fetchMemo: FetchMemoUseCase(repository: memoRepository),
            saveMemo: SaveMemoUseCase(repository: memoRepository),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: liveActivityService),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: liveActivityService),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: liveActivityService),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: liveActivityService),
            // Keychain 저장 — 앱 삭제·재설치로 무료 한도(첫날 2회·이후 1회)를 리셋하는 우회를 막는다.
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: KeychainLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: FirebaseAppUpdatePolicyService()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: appSettingsRepository),
            saveAppSettings: SaveAppSettingsUseCase(repository: appSettingsRepository),
            analytics: FirebaseAnalyticsService(),
            reconcilePremiumSettings: ReconcilePremiumSettingsUseCase(
                fetch: FetchAppSettingsUseCase(repository: appSettingsRepository),
                save: SaveAppSettingsUseCase(repository: appSettingsRepository)
            )
        )
    }
}
