//
//  FocusViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct FocusViewModelTests {

    /// 인메모리 fake로 의존성을 조립한다. 집중 탭은 노티 스케줄러만 쓰지만 `Dependencies`
    /// 묶음이 다른 필드들도 요구하므로 채워둔다. 영속 테스트에서 같은 repository를 두
    /// ViewModel 인스턴스가 공유해야 하므로 외부 주입을 허용한다.
    private func makeDependencies(
        scheduler: FakeFocusNotificationScheduler = FakeFocusNotificationScheduler(),
        focusSessionsRepository: InMemoryFocusSessionsRepository = InMemoryFocusSessionsRepository()
    ) -> (Dependencies, FakeFocusNotificationScheduler, InMemoryFocusSessionsRepository) {
        let itemRepository = InMemoryItemRepository()
        let remindersRepository = InMemoryRemindersRepository(access: .granted)
        let eventsRepository = InMemoryEventsRepository(access: .granted)
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
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepository),
            fetchEvents: FetchEventsUseCase(repository: eventsRepository),
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepository),
            focusNotifications: scheduler,
            focusAudioKeepAlive: DisabledAudioKeepAliveService(),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            fetchActiveFocusSession: FetchActiveFocusSessionUseCase(repository: focusSessionsRepository),
            saveActiveFocusSession: SaveActiveFocusSessionUseCase(repository: focusSessionsRepository),
            startFocusLiveActivity: StartFocusLiveActivityUseCase(service: DisabledLiveActivityService()),
            updateFocusLiveActivity: UpdateFocusLiveActivityUseCase(service: DisabledLiveActivityService()),
            endFocusLiveActivity: EndFocusLiveActivityUseCase(service: DisabledLiveActivityService()),
            restoreFocusLiveActivity: RestoreFocusLiveActivityUseCase(service: DisabledLiveActivityService()),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService())
        )
        return (deps, scheduler, focusSessionsRepository)
    }

    // MARK: - 초기 상태 / 시작·정지

    @Test func initialStateHasNoSessionsAndNoSelection() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.selectedSessionID == nil)
        #expect(viewModel.selectedSession == nil)
        #expect(viewModel.displayedSettings == FocusSettings.default)
        #expect(viewModel.session == nil)
    }

    @Test func startUsesSelectedSessionSettings() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 90, restDuration: 30, isRepeating: false, cycleCount: 1)
        let added = viewModel.addSession(title: "테스트", settings: custom, colorHex: "#34C759")
        viewModel.selectSession(id: added.id)

        viewModel.start()

        #expect(viewModel.session?.phase == .focus)
        #expect(viewModel.session?.remaining == 90)
        #expect(viewModel.session?.totalCycles == 1)
    }

    @Test func startWithoutSelectionUsesDefaultSettings() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

        viewModel.start()

        #expect(viewModel.session?.remaining == FocusSettings.default.focusDuration)
    }

    @Test func startIsNoopWhenAlreadyRunning() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.start()
        let first = viewModel.session

        viewModel.start()

        // 같은 인스턴스가 그대로 — 두 번째 start로 새 세션이 만들어지지 않는다.
        #expect(viewModel.session === first)
    }

    @Test func stopSessionClearsAndAbortsCurrent() {
        let (deps, scheduler, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.start()

        viewModel.stopSession()

        #expect(viewModel.session == nil)
        #expect(scheduler.cancelCount >= 1)
    }

    // MARK: - 세션 CRUD

    @Test func addSessionAppendsToList() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 30 * 60, restDuration: 5 * 60, isRepeating: true, cycleCount: 4)

        let added = viewModel.addSession(title: "독서", settings: custom, colorHex: "#FF9500")

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == added.id)
        #expect(viewModel.sessions[0].title == "독서")
        #expect(viewModel.sessions[0].settings == custom)
        #expect(viewModel.sessions[0].colorHex == "#FF9500")
    }

    @Test func updateSessionReplacesInPlace() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let original = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")
        let newSettings = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)

        viewModel.updateSession(id: original.id, title: "운동", settings: newSettings, colorHex: "#34C759")

        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions[0].id == original.id)
        #expect(viewModel.sessions[0].title == "운동")
        #expect(viewModel.sessions[0].settings == newSettings)
        #expect(viewModel.sessions[0].colorHex == "#34C759")
    }

    @Test func updateSessionWithUnknownIDIsNoop() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        viewModel.addSession(title: "원본", settings: .default, colorHex: "#FF3B30")

        viewModel.updateSession(id: UUID(), title: "다른", settings: .default, colorHex: "#FF3B30")

        #expect(viewModel.sessions[0].title == "원본")
    }

    @Test func deleteSessionRemovesFromList() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let a = viewModel.addSession(title: "A", settings: .default, colorHex: "#FF3B30")
        let b = viewModel.addSession(title: "B", settings: .default, colorHex: "#FF9500")

        viewModel.deleteSession(id: a.id)

        #expect(viewModel.sessions.map(\.id) == [b.id])
    }

    @Test func deletingSelectedSessionClearsSelection() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let added = viewModel.addSession(title: "독서", settings: .default, colorHex: "#FF3B30")
        viewModel.selectSession(id: added.id)

        viewModel.deleteSession(id: added.id)

        #expect(viewModel.selectedSessionID == nil)
    }

    @Test func deletingNonSelectedSessionKeepsSelection() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let kept = viewModel.addSession(title: "유지", settings: .default, colorHex: "#FF3B30")
        let toRemove = viewModel.addSession(title: "삭제", settings: .default, colorHex: "#FF9500")
        viewModel.selectSession(id: kept.id)

        viewModel.deleteSession(id: toRemove.id)

        #expect(viewModel.selectedSessionID == kept.id)
    }

    // MARK: - 선택

    @Test func selectSessionUpdatesDisplayedSettings() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)
        let custom = FocusSettings(focusDuration: 45 * 60, restDuration: 10 * 60, isRepeating: false, cycleCount: 1)
        let added = viewModel.addSession(title: "글쓰기", settings: custom, colorHex: "#5856D6")

        viewModel.selectSession(id: added.id)

        #expect(viewModel.selectedSession?.id == added.id)
        #expect(viewModel.displayedSettings == custom)
    }

    @Test func selectingUnknownIDKeepsDisplayedSettingsAtDefault() {
        let (deps, _, _) = makeDependencies()
        let viewModel = FocusViewModel(dependencies: deps)

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
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == storedID)
    }

    /// 저장된 selectedID가 가리키는 세션이 사라졌어도(다른 기기에서 삭제 등) sessions가
    /// 비어 있지 않으면 첫 번째를 자동 선택 — placeholder 상태로 떨어뜨리지 않는다.
    @Test func onAppearRestoresFirstSessionWhenStoredSelectionMissing() async {
        let first = FocusSession(id: UUID(), title: "A", settings: .default, colorHex: "#FF3B30")
        let second = FocusSession(id: UUID(), title: "B", settings: .default, colorHex: "#FF9500")
        let repo = InMemoryFocusSessionsRepository(
            sessions: [first, second],
            selectedID: UUID() // 어떤 세션도 가리키지 않는 임의의 id
        )
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == first.id)
    }

    /// 저장된 selectedID 자체가 없을 때(첫 실행이지만 사용자가 미리 세션을 만들었다면)도
    /// 첫 번째를 자동 선택. 위 케이스와 동일 분기지만 명시적으로 검증.
    @Test func onAppearSelectsFirstSessionWhenNoStoredSelection() async {
        let only = FocusSession(id: UUID(), title: "유일", settings: .default, colorHex: "#FF3B30")
        let repo = InMemoryFocusSessionsRepository(sessions: [only], selectedID: nil)
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == only.id)
    }

    /// sessions가 아예 비어 있으면 selectedID 영속값이 있든 없든 nil — 메인 화면은 "Cue"
    /// placeholder + 기본 설정으로 폴백.
    @Test func onAppearKeepsSelectionNilWhenNoSessions() async {
        let repo = InMemoryFocusSessionsRepository(sessions: [], selectedID: UUID())
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(viewModel.selectedSessionID == nil)
    }

    /// selectSession 호출은 영속화로 이어진다 — 같은 repository에 새 ViewModel을 붙여
    /// onAppear하면 같은 세션이 다시 떠 있다("앱 재시작" 시나리오 그대로).
    @Test func selectSessionPersistsAcrossInstances() async {
        let repo = InMemoryFocusSessionsRepository()
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)
        let a = viewModel.addSession(title: "A", settings: .default, colorHex: "#FF3B30")
        let b = viewModel.addSession(title: "B", settings: .default, colorHex: "#FF9500")

        // 첫 번째가 아닌 두 번째를 선택 — 자동 선택과 구별되게.
        viewModel.selectSession(id: b.id)
        // fire-and-forget persist Task가 actor에 도달하도록 한 박자 양보.
        await Task.yield()
        await Task.yield()

        let (deps2, _, _) = makeDependencies(focusSessionsRepository: repo)
        let restored = FocusViewModel(dependencies: deps2)
        await restored.onAppear()

        #expect(restored.selectedSessionID == b.id)
        // a도 잘 살아있는지 sanity check — sessions 자체 영속이 깨지지 않았다.
        #expect(restored.sessions.map(\.id) == [a.id, b.id])
    }

    /// 선택된 세션을 삭제하면 영속값도 nil로 — 다음 실행에서 placeholder 상태로 시작하거나
    /// 다른 세션이 남아 있으면 그 첫 번째가 자동 선택된다.
    @Test func deletingSelectedSessionPersistsNilSelection() async {
        let repo = InMemoryFocusSessionsRepository()
        let (deps, _, _) = makeDependencies(focusSessionsRepository: repo)
        let viewModel = FocusViewModel(dependencies: deps)
        let only = viewModel.addSession(title: "유일", settings: .default, colorHex: "#FF3B30")
        viewModel.selectSession(id: only.id)
        await Task.yield()

        viewModel.deleteSession(id: only.id)
        await Task.yield()
        await Task.yield()

        let storedAfterDelete = await repo.fetchSelectedSessionID()
        #expect(storedAfterDelete == nil)
    }
}
