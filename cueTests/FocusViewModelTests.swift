//
//  FocusViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct FocusViewModelTests {

    /// 인메모리 fake로 의존성을 조립한다. 진행 중 세션은 AlarmKit(시스템·기기 전용)이 구동하므로
    /// 여기선 세션 프리셋 CRUD·선택·영속만 검증한다. 영속 테스트에서 같은 repository를 두 ViewModel
    /// 인스턴스가 공유해야 하므로 외부 주입을 허용한다.
    private func makeDependencies(
        focusSessionsRepository: InMemoryFocusSessionsRepository = InMemoryFocusSessionsRepository(),
        appSettings: AppSettings = .default
    ) -> (Dependencies, InMemoryFocusSessionsRepository) {
        let itemRepository = InMemoryItemRepository()
        let remindersRepository = InMemoryRemindersRepository(access: .granted)
        let reminderSortRepository = InMemoryReminderSortRepository()
        let eventsRepository = InMemoryEventsRepository(access: .granted)
        let appSettingsRepository = InMemoryAppSettingsRepository(storage: appSettings)
        let deps = Dependencies(
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
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            fetchMemo: FetchMemoUseCase(repository: InMemoryMemoRepository()),
            saveMemo: SaveMemoUseCase(repository: InMemoryMemoRepository()),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService()),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: DisabledLiveActivityService()),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: appSettingsRepository),
            saveAppSettings: SaveAppSettingsUseCase(repository: appSettingsRepository)
        )
        return (deps, focusSessionsRepository)
    }

    // MARK: - 초기 상태

    @Test func initialStateHasNoSessionsAndNoSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.selectedSessionID == nil)
        #expect(viewModel.selectedSession == nil)
        #expect(viewModel.displayedSettings == FocusSettings.default)
        #expect(viewModel.isActive == false)
    }

    // MARK: - 무료 세션 한도

    /// 무료 사용자는 세션 프리셋 1개까지 — 두 번째 추가는 nil을 반환하고 목록은 그대로.
    /// (뷰가 nil을 받으면 Premium 토스트를 띄운다.)
    @Test func freeUserLimitedToOneSession() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)   // 기본 무료

        let first = viewModel.addSession(title: "첫 세션", settings: .default, colorHex: "#FF3B30")
        let second = viewModel.addSession(title: "둘째 세션", settings: .default, colorHex: "#FF9500")

        #expect(first != nil)
        #expect(second == nil)
        #expect(viewModel.sessions.count == 1)
    }

    // MARK: - 세션 CRUD

    @Test func addSessionAppendsToList() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let custom = FocusSettings(focusDuration: 30 * 60, restDuration: 5 * 60, isRepeating: true, cycleCount: 4)

        let added = viewModel.addSession(title: "독서", settings: custom, colorHex: "#FF9500")!

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == added.id)
        #expect(viewModel.sessions[0].title == "독서")
        #expect(viewModel.sessions[0].settings == custom)
        #expect(viewModel.sessions[0].colorHex == "#FF9500")
    }

    @Test func updateSessionReplacesInPlace() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let original = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")!
        let newSettings = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)

        viewModel.updateSession(id: original.id, title: "운동", settings: newSettings, colorHex: "#34C759")

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == original.id)
        #expect(viewModel.sessions[0].title == "운동")
        #expect(viewModel.sessions[0].settings == newSettings)
        #expect(viewModel.sessions[0].colorHex == "#34C759")
    }

    @Test func updateSessionWithUnknownIDIsNoop() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        viewModel.addSession(title: "원본", settings: .default, colorHex: "#FF3B30")

        viewModel.updateSession(id: UUID(), title: "다른", settings: .default, colorHex: "#FF3B30")

        #expect(viewModel.sessions[0].title == "원본")
    }

    @Test func deleteSessionRemovesFromList() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let a = viewModel.addSession(title: "A", settings: .default, colorHex: "#FF3B30")!
        let b = viewModel.addSession(title: "B", settings: .default, colorHex: "#FF9500")!

        viewModel.deleteSession(id: a.id)

        #expect(viewModel.sessions.map(\.id) == [b.id])
    }

    @Test func deletingSelectedSessionClearsSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let added = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")!
        viewModel.selectSession(id: added.id)

        viewModel.deleteSession(id: added.id)

        #expect(viewModel.selectedSessionID == nil)
    }

    @Test func deletingNonSelectedSessionKeepsSelection() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let kept = viewModel.addSession(title: "유지", settings: .default, colorHex: "#FF3B30")!
        let toRemove = viewModel.addSession(title: "삭제", settings: .default, colorHex: "#FF9500")!
        viewModel.selectSession(id: kept.id)

        viewModel.deleteSession(id: toRemove.id)

        #expect(viewModel.selectedSessionID == kept.id)
    }

    // MARK: - 선택

    @Test func selectSessionUpdatesDisplayedSettings() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let custom = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)
        let added = viewModel.addSession(title: "글쓰기", settings: custom, colorHex: "#5856D6")!

        viewModel.selectSession(id: added.id)

        #expect(viewModel.selectedSession?.id == added.id)
        #expect(viewModel.displayedSettings == custom)
    }

    @Test func selectingUnknownIDKeepsDisplayedSettingsAtDefault() {
        let (deps, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        viewModel.selectSession(id: UUID())

        #expect(viewModel.selectedSession == nil)
        #expect(viewModel.displayedSettings == FocusSettings.default)
    }

    // MARK: - 선택 영속화 / 복원

    /// 저장된 selectedID가 sessions에 그대로 존재하면 그 세션이 복원된다 —
    /// "지난 번에 고른 세션이 앱을 다시 켜도 그대로 떠 있다"가 핵심 기능.
    @Test func onAppearRestoresStoredSelectionWhenSessionStillExists() async {
        let storedID = UUID()
        let session = FocusSession(id: storedID, title: "집중", settings: .default, colorHex: "#FF3B30")
        let repo = InMemoryFocusSessionsRepository(sessions: [session], selectedID: storedID)
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == storedID)
    }

    /// 저장된 selectedID가 가리키는 세션이 사라졌어도 sessions가 비어 있지 않으면 첫 번째를 자동 선택.
    @Test func onAppearRestoresFirstSessionWhenStoredSelectionMissing() async {
        let first = FocusSession(id: UUID(), title: "A", settings: .default, colorHex: "#FF3B30")
        let second = FocusSession(id: UUID(), title: "B", settings: .default, colorHex: "#FF9500")
        let repo = InMemoryFocusSessionsRepository(
            sessions: [first, second],
            selectedID: UUID()
        )
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == first.id)
    }

    /// 저장된 selectedID 자체가 없을 때도 첫 번째를 자동 선택.
    @Test func onAppearSelectsFirstSessionWhenNoStoredSelection() async {
        let only = FocusSession(id: UUID(), title: "유일", settings: .default, colorHex: "#FF3B30")
        let repo = InMemoryFocusSessionsRepository(sessions: [only], selectedID: nil)
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == only.id)
    }

    /// sessions가 아예 비어 있으면 selectedID 영속값이 있든 없든 nil.
    @Test func onAppearKeepsSelectionNilWhenNoSessions() async {
        let repo = InMemoryFocusSessionsRepository(sessions: [], selectedID: UUID())
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == nil)
    }

    /// selectSession 호출은 영속화로 이어진다 — 같은 repository에 새 ViewModel을 붙여 onAppear하면 같은 세션이 다시 떠 있다.
    @Test func selectSessionPersistsAcrossInstances() async {
        let repo = InMemoryFocusSessionsRepository()
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let a = viewModel.addSession(title: "A", settings: .default, colorHex: "#FF3B30")!
        let b = viewModel.addSession(title: "B", settings: .default, colorHex: "#FF9500")!

        viewModel.selectSession(id: b.id)
        await Task.yield()
        await Task.yield()

        let (deps2, _) = makeDependencies(focusSessionsRepository: repo)
        let restored = FocusViewModel(dependencies: deps2, premiumStore: PremiumStore(previewIsPremium: true))
        await restored.onAppear()

        #expect(restored.selectedSessionID == b.id)
        #expect(restored.sessions.map(\.id) == [a.id, b.id])
    }

    /// 선택된 세션을 삭제하면 영속값도 nil로.
    @Test func deletingSelectedSessionPersistsNilSelection() async {
        let repo = InMemoryFocusSessionsRepository()
        let (deps, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps, premiumStore: PremiumStore(previewIsPremium: true))
        let only = viewModel.addSession(title: "유일", settings: .default, colorHex: "#FF3B30")!
        viewModel.selectSession(id: only.id)
        await Task.yield()

        viewModel.deleteSession(id: only.id)
        await Task.yield()
        await Task.yield()

        let storedAfterDelete = await repo.fetchSelectedSessionID()
        #expect(storedAfterDelete == nil)
    }

    // MARK: - 알람 목록 변화 채택 게이트

    /// 진행 중 + 전환 아님 + 현재 알람이 목록에서 사라짐 → 재채택해야 한다
    /// (잠금화면 "다음 단계" 탭·종료를 인앱에 반영하는 기존 경로).
    @Test func adoptsWhenCurrentAlarmDisappearsOutsideTransition() {
        let current = UUID()
        let should = FocusViewModel.shouldAdoptAfterAlarmChange(
            isActive: true, isTransitioning: false, currentAlarmID: current, alarmIDs: [UUID()]
        )
        #expect(should == true)
    }

    /// 단계 전환 중(이전 알람 취소 ~ 새 알람 예약 완료 사이)의 목록 변화는 무시 —
    /// 이 창에서 재채택하면 Activity가 아직 없어 세션이 꺼져버리는 race가 버그의 원인.
    @Test func ignoresAlarmChangeWhileTransitioning() {
        let current = UUID()
        let should = FocusViewModel.shouldAdoptAfterAlarmChange(
            isActive: true, isTransitioning: true, currentAlarmID: current, alarmIDs: []
        )
        #expect(should == false)
    }

    /// 현재 알람이 목록에 그대로 있으면(일시정지·발화 등 상태 변화) 재채택하지 않는다.
    @Test func ignoresAlarmChangeWhenCurrentAlarmStillPresent() {
        let current = UUID()
        let should = FocusViewModel.shouldAdoptAfterAlarmChange(
            isActive: true, isTransitioning: false, currentAlarmID: current, alarmIDs: [current]
        )
        #expect(should == false)
    }

    /// 세션이 없거나(idle) 예약이 아직 안 끝났으면(currentAlarmID nil) 무시 —
    /// 시작 직후 "알람 없음=종료" 오판으로 꺼지는 것을 막는 기존 가드 유지.
    @Test func ignoresAlarmChangeWhenIdleOrScheduling() {
        #expect(FocusViewModel.shouldAdoptAfterAlarmChange(
            isActive: false, isTransitioning: false, currentAlarmID: UUID(), alarmIDs: []
        ) == false)
        #expect(FocusViewModel.shouldAdoptAfterAlarmChange(
            isActive: true, isTransitioning: false, currentAlarmID: nil, alarmIDs: []
        ) == false)
    }
}
