//
//  ReminderViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ReminderViewModelTests {

    private let listA = ReminderList(id: "A", title: "회사", colorHex: nil)
    private let listB = ReminderList(id: "B", title: "개인", colorHex: nil)

    /// 인메모리 fake로 의존성을 조립한다 (EventKit·SwiftData 없이 동작).
    private func makeDependencies(
        access: RemindersAccess = .granted,
        lists: [ReminderList] = [],
        reminders: [Reminder] = [],
        sortSettings: [String: ReminderSortSettings] = [:],
        liveActivityService: any LiveActivityService = DisabledLiveActivityService(),
        appSettings: AppSettings = .default,
        analytics: (any AnalyticsService)? = nil
    ) -> Dependencies {
        makeDependencies(
            remindersRepository: InMemoryRemindersRepository(
                access: access, lists: lists, reminders: reminders
            ),
            sortSettings: sortSettings,
            liveActivityService: liveActivityService,
            appSettings: appSettings,
            analytics: analytics
        )
    }

    /// 프리미엄 상태를 흉내내는 스토어 — 엔타이틀먼트가 있는 no-op 서비스로 만들고 refresh해 둔다.
    private func premiumStore() async -> PremiumStore {
        let store = PremiumStore(service: DisabledPurchaseService(entitled: [PremiumProduct.yearly.id]))
        await store.refresh()
        return store
    }

    /// 리포지토리를 직접 주입하는 코어 빌더 — 외부 변경/로딩 시뮬레이션처럼 같은 repo 인스턴스를
    /// fetch·emit 양쪽에 써야 하는 테스트에서 gated fake를 꽂을 수 있게 한다.
    private func makeDependencies(
        remindersRepository: any RemindersRepository,
        sortSettings: [String: ReminderSortSettings] = [:],
        liveActivityService: any LiveActivityService = DisabledLiveActivityService(),
        appSettings: AppSettings = .default,
        analytics: (any AnalyticsService)? = nil
    ) -> Dependencies {
        let reminderSortRepository = InMemoryReminderSortRepository(storage: sortSettings)
        let itemRepository = InMemoryItemRepository()
        let eventsRepository = InMemoryEventsRepository(access: .granted)
        let focusSessionsRepository = InMemoryFocusSessionsRepository()
        var dependencies = Dependencies(
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
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            startSampleLiveActivities: StartSampleLiveActivitiesUseCase(
                startSchedule: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
                startReminder: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService())
            ),
            fetchMemo: FetchMemoUseCase(repository: InMemoryMemoRepository()),
            saveMemo: SaveMemoUseCase(repository: InMemoryMemoRepository()),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService()),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: DisabledLiveActivityService()),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: DisabledAppUpdatePolicyService()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: InMemoryAppSettingsRepository(storage: appSettings)),
            saveAppSettings: SaveAppSettingsUseCase(repository: InMemoryAppSettingsRepository(storage: appSettings))
        )
        // 프리페치의 프롬프트-없는 권한 조회도 같은 repo를 보게 배선 — 기본값(별도 인메모리)은
        // 항상 미결정이라 프리페치가 무조건 건너뛰게 된다.
        dependencies.currentRemindersAccess = CurrentRemindersAccessUseCase(repository: remindersRepository)
        dependencies.moveReminder = MoveReminderUseCase(repository: remindersRepository)
        if let analytics { dependencies.analytics = analytics }
        return dependencies
    }

    private func reminder(
        id: String, title: String = "할 일",
        isCompleted: Bool = false, dueDate: Date? = nil,
        includesTime: Bool = false, creationDate: Date? = nil, listID: String
    ) -> Reminder {
        Reminder(
            id: id, title: title, isCompleted: isCompleted,
            notes: nil, dueDate: dueDate, includesTime: includesTime,
            creationDate: creationDate, listID: listID
        )
    }

    @Test func onAppearGrantsAccessAndLoadsData() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .notDetermined,
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")]
        ))

        await viewModel.onAppear()

        #expect(viewModel.access == .granted)
        #expect(viewModel.lists == [listA])
        #expect(viewModel.allReminders.count == 1)
    }

    /// 항상 표시 자동 게시(Premium 전용) — 권한이 있으면 현재 선택 스냅샷으로 LA를 시작한다(쿼터 미소비).
    @Test func alwaysOnStartsReminderLiveActivity() async throws {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(
                lists: [listA],
                reminders: [reminder(id: "1", listID: "A")],
                liveActivityService: service
            ),
            premiumStore: await premiumStore()
        )

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startReminderCalls.count == 1)
    }

    /// 항상 표시는 Premium 전용 — 무료(구독 만료 포함)는 저장값이 켜져 있어도 자동 게시하지 않는다.
    @Test func alwaysOnSkipsWhenNotPremium() async {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")],
            liveActivityService: service
        ))

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == false)
        #expect(await service.startReminderCalls.isEmpty)
    }

    /// Premium(무제한)이면 켜기 버튼이 `.unlimited`로 그대로 LA를 켠다 — 설정 "라이브 항상 표시"와 무관.
    @Test func togglePremiumUserStartsReminderLiveActivity() async {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(
                lists: [listA],
                reminders: [reminder(id: "1", listID: "A")],
                liveActivityService: service
            ),
            premiumStore: await premiumStore()
        )
        await viewModel.onAppear()

        let verdict = await viewModel.toggleLiveActivity(listTitle: "회사")

        #expect(verdict == .unlimited)
        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startReminderCalls.count == 1)
    }

    /// 설정에서 숨긴 리스트는 목록 칩(visibleLists)과 할일 스냅샷 어디에서도 빠진다.
    @Test func hiddenReminderListsAreExcludedEverywhere() async {
        var settings = AppSettings.default
        settings.hiddenReminderListIDs = ["B"]
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [reminder(id: "a", listID: "A"), reminder(id: "b", listID: "B")],
            appSettings: settings
        ))
        await viewModel.onAppear()

        #expect(viewModel.visibleLists.map(\.id) == ["A"])                     // 칩에서 B 제외
        #expect(viewModel.allModeSections.allSatisfy { $0.list.id != "B" })    // 전체 섹션에서 B 제외
        #expect(!viewModel.visibleReminders.contains { $0.listID == "B" })     // 스냅샷에서 B 항목 제외
    }

    /// 숨김 목록 변경이 즉시 반영되고, 보고 있던 리스트가 숨겨지면 '전체'로 떨어진다.
    @Test func applyingHiddenListResetsSelectionOffHiddenList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA, listB]))
        await viewModel.onAppear()
        viewModel.select(listB)
        #expect(viewModel.selection == .list("B"))

        viewModel.applyHiddenReminderLists(["B"])

        #expect(viewModel.selection == .systemFilter(.all))
        #expect(viewModel.visibleLists.map(\.id) == ["A"])
    }

    /// 설정의 할일 범위가 "today"면 오늘 마감 항목만 스냅샷에 담는다.
    @Test func alwaysOnUsesConfiguredScope() async throws {
        var settings = AppSettings.default
        settings.liveAlwaysOnReminderScopeID = "today"
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(
                lists: [listA],
                reminders: [
                    reminder(id: "due-today", dueDate: Date(), listID: "A"),
                    reminder(id: "no-due", listID: "A"),
                ],
                liveActivityService: service,
                appSettings: settings
            ),
            premiumStore: await premiumStore()
        )

        await viewModel.startAlwaysOnLiveActivity()

        let call = try #require(await service.startReminderCalls.first)
        #expect(call.items.map(\.id) == ["due-today"])
    }

    /// 권한이 거부돼 있으면 자동 게시하지 않는다.
    @Test func alwaysOnSkipsWhenAccessDenied() async {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(
                access: .denied,
                liveActivityService: service
            ),
            premiumStore: await premiumStore()
        )

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == false)
        #expect(await service.startReminderCalls.isEmpty)
    }

    @Test func externalChangeReloadsRemindersAfterFirstLoad() async throws {
        // makeDependencies는 repo를 내부 생성 — 외부 변경 시뮬레이션을 위해 직접 조립.
        // 같은 repo 인스턴스가 ViewModel의 fetch와 변경 emit 양쪽에 쓰이도록.
        let repo = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let sortRepo = InMemoryReminderSortRepository()
        let itemRepo = InMemoryItemRepository()
        let eventsRepo = InMemoryEventsRepository(access: .granted)
        let focusRepo = InMemoryFocusSessionsRepository()
        let deps = Dependencies(
            fetchItems: FetchItemsUseCase(repository: itemRepo),
            addItem: AddItemUseCase(repository: itemRepo),
            deleteItem: DeleteItemUseCase(repository: itemRepo),
            requestRemindersAccess: RequestRemindersAccessUseCase(repository: repo),
            fetchReminderLists: FetchReminderListsUseCase(repository: repo),
            fetchReminders: FetchRemindersUseCase(repository: repo),
            toggleReminderCompletion: ToggleReminderCompletionUseCase(repository: repo),
            addReminder: AddReminderUseCase(repository: repo),
            updateReminder: UpdateReminderUseCase(repository: repo),
            deleteReminder: DeleteReminderUseCase(repository: repo),
            addReminderList: AddReminderListUseCase(repository: repo),
            updateReminderList: UpdateReminderListUseCase(repository: repo),
            deleteReminderList: DeleteReminderListUseCase(repository: repo),
            observeRemindersChanges: ObserveRemindersChangesUseCase(repository: repo),
            fetchReminderSortSettings: FetchReminderSortSettingsUseCase(repository: sortRepo),
            saveReminderSortSettings: SaveReminderSortSettingsUseCase(repository: sortRepo),
            requestEventsAccess: RequestEventsAccessUseCase(repository: eventsRepo),
            fetchEvents: FetchEventsUseCase(repository: eventsRepo),
            fetchCalendars: FetchCalendarsUseCase(repository: eventsRepo),
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepo),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusRepo),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusRepo),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusRepo),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusRepo),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: DisabledLiveActivityService()),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            startSampleLiveActivities: StartSampleLiveActivitiesUseCase(
                startSchedule: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
                startReminder: StartReminderLiveActivityUseCase(service: DisabledLiveActivityService())
            ),
            fetchMemo: FetchMemoUseCase(repository: InMemoryMemoRepository()),
            saveMemo: SaveMemoUseCase(repository: InMemoryMemoRepository()),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService()),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: DisabledLiveActivityService()),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            checkForcedUpdate: CheckForcedUpdateUseCase(service: DisabledAppUpdatePolicyService()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: InMemoryAppSettingsRepository()),
            saveAppSettings: SaveAppSettingsUseCase(repository: InMemoryAppSettingsRepository())
        )
        let viewModel = ReminderViewModel(dependencies: deps)
        await viewModel.onAppear()
        #expect(viewModel.allReminders.isEmpty)

        // 외부(미리 알림 앱) 변경 시뮬레이션 — 데이터 추가 후 변경 신호 emit.
        try await repo.addReminder(
            title: "외부 추가", notes: nil,
            dueDate: nil, includesTime: false,
            recurrence: nil,
            toListID: listA.id
        )
        await repo.emitChange()
        // observe task가 신호를 처리할 시간 — Task hop이 끝나도록 짧게 yield.
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.allReminders.contains { $0.title == "외부 추가" })
    }

    /// 외부 변경(자기 쓰기가 유발한 EventKit 알림 포함)으로 인한 reload는 **로딩 인디케이터를
    /// 띄우지 않아야** 한다 — Apple 미리알림처럼 엔터 시 깜빡임/스피너 없이 반영. isLoading은
    /// 최초 적재에만 쓴다. gated repo로 reload를 fetchReminders에서 붙잡아 "진행 중" 순간을 관측.
    @Test func externalChangeReloadDoesNotShowLoadingIndicator() async throws {
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()
        #expect(viewModel.isLoading == false)

        // 외부 변경 발생 — 다음 fetchReminders를 게이트로 붙잡아 reload를 진행 중 상태로 고정.
        try await base.addReminder(
            title: "외부", notes: nil, dueDate: nil, includesTime: false, recurrence: nil, toListID: listA.id
        )
        await repo.closeGate()
        await base.emitChange()

        // reload가 fetchReminders에서 대기하기 시작할 때까지 (bounded — 최대 ~1s).
        var reloadInFlight = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { reloadInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(reloadInFlight)
        // 리로드가 진행 중인데도 인디케이터가 떠 있으면 안 된다.
        #expect(viewModel.isLoading == false)

        await repo.releaseFetch()
    }

    /// 저장(add)은 재조회(fetch round-trip)가 끝나기 **전에** 이미 목록에 항목을 낙관적으로
    /// 반영해야 한다 — 재조회 공백(EventKit 수백 ms) 동안 행이 비어 보이는 깜빡임 제거의 계약.
    @Test func addAppliesOptimisticallyBeforeRefetchCompletes() async throws {
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()

        // add 뒤의 reconcile fetch를 게이트로 붙잡아 "재조회 진행 중" 순간을 관측.
        await repo.closeGate()
        let task = Task { await viewModel.add(title: "새 항목", toListID: listA.id) }

        var reloadInFlight = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { reloadInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(reloadInFlight)
        // 재조회가 아직 안 끝났는데도 새 항목이 이미 화면 목록에 있어야 한다.
        #expect(viewModel.allReminders.contains { $0.title == "새 항목" })

        await repo.releaseFetch()
        await task.value
        #expect(viewModel.allReminders.contains { $0.title == "새 항목" })
    }

    /// 수정(update)도 재조회 완료 전에 해당 항목이 로컬에서 새 값으로 치환돼 있어야 한다 —
    /// 편집 종료 직후 옛 제목이 잠깐 보였다 바뀌는 플래시 제거의 계약.
    @Test func updateAppliesOptimisticallyBeforeRefetchCompletes() async throws {
        let base = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [reminder(id: "1", title: "옛 제목", listID: "A")]
        )
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()

        await repo.closeGate()
        let task = Task { await viewModel.update(reminderID: "1", title: "새 제목", notes: nil) }

        var reloadInFlight = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { reloadInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(reloadInFlight)
        // 재조회가 아직 안 끝났는데도 제목이 이미 새 값이어야 한다(같은 id, in-place).
        #expect(viewModel.allReminders.first { $0.id == "1" }?.title == "새 제목")

        await repo.releaseFetch()
        await task.value
        #expect(viewModel.allReminders.first { $0.id == "1" }?.title == "새 제목")
    }

    /// add는 낙관 반영까지만 하고 **재조회를 기다리지 않고 반환**해야 한다 — 뷰가 "새 행이
    /// 목록에 실린 직후" 입력칸을 비울 수 있어야 텍스트가 사라지는 공백 구간이 없다.
    @Test func addReturnsWithoutAwaitingReconcileFetch() async throws {
        @MainActor final class Flag { var isSet = false }
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()

        await repo.closeGate()   // reconcile fetch를 붙잡는다.
        let finished = Flag()
        let task = Task {
            await viewModel.add(title: "새 항목", toListID: listA.id)
            finished.isSet = true
        }

        var reloadInFlight = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { reloadInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(reloadInFlight)
        try await Task.sleep(nanoseconds: 100_000_000)
        // 재조회가 게이트에 붙잡혀 있어도 add는 이미 반환됐어야 한다.
        #expect(finished.isSet)

        await repo.releaseFetch()
        await task.value
    }

    /// update는 저장소 반환 **전에** 새 값을 선반영해야 한다 — 편집 종료로 행이 읽기 모드로
    /// 바뀌는 순간 옛 제목이 저장 왕복 시간만큼 보이는 플래시를 없애는 계약.
    @Test func updateAppliesNewValuesBeforeRepositoryReturns() async throws {
        let base = InMemoryRemindersRepository(
            access: .granted, lists: [listA],
            reminders: [reminder(id: "1", title: "옛 제목", listID: "A")]
        )
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()

        await repo.closeUpdateGate()   // EventKit 쓰기 자체를 붙잡는다.
        let task = Task { await viewModel.update(reminderID: "1", title: "새 제목", notes: nil) }

        var updateInFlight = false
        for _ in 0..<200 {
            if await repo.isUpdateWaiting { updateInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(updateInFlight)
        // 저장이 아직 안 끝났는데도 로컬 제목은 이미 새 값이어야 한다.
        #expect(viewModel.allReminders.first { $0.id == "1" }?.title == "새 제목")

        await repo.releaseUpdate()
        await task.value
        #expect(viewModel.allReminders.first { $0.id == "1" }?.title == "새 제목")
    }

    /// 비행 중이던 **오래된 재조회가 늦게 착지해도** 그 사이의 낙관 반영을 덮어쓰지 않는다 —
    /// 빠른 연속 저장 시 첫 add의 reconcile(둘째 항목이 없는 스냅샷)이 둘째 add의 낙관 삽입
    /// 뒤에 착지하면 항목이 잠깐 사라졌다 재등장하는 깜빡임이 재발하므로, 낡은 결과는 폐기한다.
    @Test func staleReconcileDoesNotClobberNewerOptimisticInsert() async throws {
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))
        await viewModel.onAppear()
        let baseline = await repo.fetchCount

        await repo.closeGate()
        await viewModel.add(title: "첫", toListID: listA.id)
        // 첫 add의 reconcile이 (둘째가 없는) 스냅샷을 뜨고 게이트에 붙잡힐 때까지.
        var firstInFlight = false
        for _ in 0..<200 {
            if await repo.fetchCount >= baseline + 1, await repo.isFetchWaiting {
                firstInFlight = true; break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(firstInFlight)

        await viewModel.add(title: "둘", toListID: listA.id)   // 낙관 삽입: 첫+둘
        #expect(viewModel.allReminders.contains { $0.title == "둘" })

        // 오래된(둘이 없는) 첫 reconcile만 착지시킨다 — 낡은 결과는 폐기돼야 한다.
        await repo.releaseNextFetch()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(viewModel.allReminders.contains { $0.title == "둘" })
        #expect(viewModel.allReminders.contains { $0.title == "첫" })

        // 남은 최신 reconcile까지 착지 — 최종 상태도 둘 다 유지.
        await repo.releaseFetch()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(viewModel.allReminders.contains { $0.title == "둘" })
        #expect(viewModel.allReminders.contains { $0.title == "첫" })
    }

    /// 리스트 애니메이션은 **제거 경로(완료 체크·삭제)에서만** 발동한다 — add까지 id 배열
    /// 변화로 애니메이션하면 새 행이 250ms 페이드-인되며 "사라졌다 나타나는" 깜빡임으로
    /// 보인다(실기기 확인). 뷰는 이 틱을 `.animation(value:)`에 걸어 삽입은 즉시 그린다.
    @Test func addDoesNotBumpListAnimationTick() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()
        let initial = viewModel.listAnimationTick

        await viewModel.add(title: "새 항목")

        #expect(viewModel.listAnimationTick == initial)
    }

    /// 완료 토글은 행 제거(또는 해제 시 복귀)를 애니메이션해야 하므로 틱을 올린다.
    @Test func toggleBumpsListAnimationTick() async {
        let target = reminder(id: "1", listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()
        let initial = viewModel.listAnimationTick

        await viewModel.toggle(target)

        #expect(viewModel.listAnimationTick == initial + 1)
    }

    /// 삭제도 행 제거 애니메이션 경로 — 틱을 올린다.
    @Test func deleteBumpsListAnimationTick() async {
        let target = reminder(id: "1", listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()
        let initial = viewModel.listAnimationTick

        await viewModel.delete(target)

        #expect(viewModel.listAnimationTick == initial + 1)
    }

    /// 억제 창은 쓰기 **시작** 시점에 열려야 한다 — EventKit은 save 직후(재조회 완료 전)에
    /// 에코를 되쏘므로, 재조회 뒤에 열면 에코가 창이 열리기 전에 통과해 전체 reload를 유발한다.
    @Test func echoArrivingDuringAddDoesNotTriggerExtraReload() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(remindersRepository: repo),
            now: { clock.now }
        )
        await viewModel.onAppear()
        let baseline = await repo.fetchCount

        await repo.closeGate()
        let task = Task { await viewModel.add(title: "새 항목", toListID: listA.id) }
        var reloadInFlight = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { reloadInFlight = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(reloadInFlight)

        // 저장 직후·재조회 완료 전에 도착한 에코 — 추가 reload(fetch)를 만들면 안 된다.
        await base.emitChange()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(await repo.fetchCount == baseline + 1)

        await repo.releaseFetch()
        await task.value
    }

    /// 자기 쓰기(add) 직후 억제 창 이내에 온 외부 변경 에코는 추가 reload를 유발하지 않는다 —
    /// 인라인 편집→새 행 포커스 이동 중 remount로 커서가 끊기던 문제를 막는다. 창 밖의 진짜
    /// 외부 변경은 정상 reload된다.
    @Test func selfWriteEchoWithinWindowSkipsReload() async throws {
        let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(
            dependencies: makeDependencies(remindersRepository: repo),
            now: { clock.now }
        )
        await viewModel.onAppear()

        let beforeAdd = await repo.fetchCount
        await viewModel.add(title: "새 항목", toListID: listA.id)   // 자기 쓰기 → 억제 창 open + 백그라운드 reconcile 1회
        // reconcile은 add 반환 후 백그라운드로 돌므로, 완료(fetch +1)까지 bounded 대기.
        var afterAdd = beforeAdd
        for _ in 0..<200 {
            afterAdd = await repo.fetchCount
            if afterAdd >= beforeAdd + 1 { break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(afterAdd == beforeAdd + 1)

        // 억제 창 이내 에코 → 무시.
        await base.emitChange()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await repo.fetchCount == afterAdd)

        // 창 밖(시계 전진)의 진짜 외부 변경 → reload.
        clock.now = clock.now.addingTimeInterval(5)
        await base.emitChange()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(await repo.fetchCount == afterAdd + 1)
    }


    @Test func onAppearWithDeniedAccessLoadsNothing() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .denied, lists: [listA]
        ))

        await viewModel.onAppear()

        #expect(viewModel.access == .denied)
        #expect(viewModel.lists.isEmpty)
    }

    // MARK: - 초기 선택 (설정의 할일 기본 화면)

    /// 기본 설정(tasksDefaultScopeID = "all")이면 진입 시 '전체' 필터로 시작한다.
    @Test func initialSelectionDefaultsToAllFilter() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA, listB]))

        await viewModel.onAppear()

        #expect(viewModel.selection == .systemFilter(.all))
    }

    /// 설정이 "today"면 진입 시 오늘 필터로 시작한다.
    @Test func initialSelectionHonorsTodaySetting() async {
        var settings = AppSettings.default
        settings.tasksDefaultScopeID = "today"
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB], appSettings: settings
        ))

        await viewModel.onAppear()

        #expect(viewModel.selection == .systemFilter(.today))
    }

    /// 설정이 사용자 리스트 id면 진입 시 그 리스트로 시작한다.
    @Test func initialSelectionHonorsListSetting() async {
        var settings = AppSettings.default
        settings.tasksDefaultScopeID = "B"
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB], appSettings: settings
        ))

        await viewModel.onAppear()

        #expect(viewModel.selectedListID == "B")
    }

    /// 설정이 가리키던 리스트가 삭제돼 없으면 첫 리스트로 폴백한다.
    @Test func initialSelectionFallsBackToFirstListWhenScopeListMissing() async {
        var settings = AppSettings.default
        settings.tasksDefaultScopeID = "ZZZ"   // 존재하지 않는 리스트 id
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB], appSettings: settings
        ))

        await viewModel.onAppear()

        #expect(viewModel.selectedListID == "A")
    }

    @Test func visibleRemindersShowsOnlySelectedList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", listID: "A"),
                reminder(id: "2", listID: "B"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.select(listB)

        #expect(viewModel.visibleReminders.map(\.id) == ["2"])
    }

    @Test func visibleRemindersHidesCompleted() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", isCompleted: false, listID: "A"),
                reminder(id: "2", isCompleted: true, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        #expect(viewModel.visibleReminders.map(\.id) == ["1"])
    }

    // MARK: - System filter (오늘/예정/전체)

    /// 오늘 필터 — 오늘 자정 이전 마감(overdue 포함) 미완료만. 완료된 항목·마감 없음·미래는 제외.
    @Test func todayFilterIncludesOverdueAndTodayDue() async {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let yesterdayNoon = startOfToday.addingTimeInterval(-12 * 60 * 60)
        let todayNoon = startOfToday.addingTimeInterval(12 * 60 * 60)
        let tomorrowNoon = startOfToday.addingTimeInterval(36 * 60 * 60)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "overdue", dueDate: yesterdayNoon, listID: "A"),
                reminder(id: "today", dueDate: todayNoon, listID: "A"),
                reminder(id: "future", dueDate: tomorrowNoon, listID: "A"),
                reminder(id: "nodue", listID: "A"),
                reminder(id: "completed", isCompleted: true, dueDate: todayNoon, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.today)

        #expect(viewModel.visibleReminders.map(\.id).sorted() == ["overdue", "today"])
    }

    /// 예정 필터 — 마감일이 있는 모든 미완료. 마감 없음·완료는 제외.
    @Test func scheduledFilterIncludesAllDueIncomplete() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "due-past", dueDate: now.addingTimeInterval(-86400), listID: "A"),
                reminder(id: "due-future", dueDate: now.addingTimeInterval(86400), listID: "A"),
                reminder(id: "nodue", listID: "A"),
                reminder(id: "completed", isCompleted: true, dueDate: now, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.scheduled)

        #expect(viewModel.visibleReminders.map(\.id).sorted() == ["due-future", "due-past"])
    }

    /// 전체 필터 — 모든 미완료(마감 없어도). 완료는 제외.
    @Test func allFilterIncludesAllIncomplete() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", listID: "A"),
                reminder(id: "2", listID: "B"),
                reminder(id: "completed", isCompleted: true, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.all)

        #expect(viewModel.visibleReminders.map(\.id).sorted() == ["1", "2"])
    }

    /// 시스템 필터에서 add() — isDefault인 리스트가 있으면 거기로 저장(로케일 무관 —
    /// 기본 목록 이름은 기기 언어에 따라 "미리 알림"/"Reminders" 등으로 달라지므로 플래그로 판별).
    @Test func addInSystemFilterUsesDefaultList() async {
        let defaultList = ReminderList(id: "DEF", title: "Reminders", colorHex: nil, isDefault: true)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, defaultList]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.today)
        await viewModel.add(title: "오늘 새 일")

        let added = viewModel.allReminders.first { $0.title == "오늘 새 일" }
        #expect(added?.listID == "DEF")
    }

    /// add()에 `toListID`를 명시하면 selection 모드 무관 그 리스트로 저장 —
    /// `.all` 모드 섹션별 입력 row가 자기 섹션의 listID를 명시할 때 쓰는 경로.
    @Test func addWithExplicitTargetListIDIgnoresSelection() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB]
        ))
        await viewModel.onAppear()
        // selection 모드와 무관하게 toListID="B"가 우선.

        await viewModel.add(title: "B 섹션 입력", toListID: "B")

        let added = viewModel.allReminders.first { $0.title == "B 섹션 입력" }
        #expect(added?.listID == "B")
    }

    /// 시스템 필터에서 add() — isDefault 리스트가 없으면 `lists.first`로 fallback.
    @Test func addInSystemFilterFallsBackToFirstList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.scheduled)
        await viewModel.add(title: "마감 있는 새 일")

        let added = viewModel.allReminders.first { $0.title == "마감 있는 새 일" }
        #expect(added?.listID == "A")
    }

    /// 전체(.all) visibleReminders는 **마감일 오름차순**(가까운 순) — 화면은 `allModeSections`로
    /// 따로 그리므로 이 평탄 목록은 라이브 액티비티 스냅샷 전용이다. 마감 없음은 맨 뒤.
    @Test func allFilterSortsByDueDateForLiveActivity() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                // 생성순과 어긋나게 두고 마감일 순으로 정렬되는지 본다. 마감 없는 항목은 맨 뒤.
                reminder(id: "due-near", dueDate: now.addingTimeInterval(3600),
                         creationDate: now.addingTimeInterval(20), listID: "A"),
                reminder(id: "due-far", dueDate: now.addingTimeInterval(7200),
                         creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "no-due", creationDate: now.addingTimeInterval(5), listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.all)

        // 마감 가까운 순 → due-near, due-far, 마감 없는 no-due는 맨 뒤.
        #expect(viewModel.visibleReminders.map(\.id) == ["due-near", "due-far", "no-due"])
    }

    /// 예정(.scheduled) visibleReminders는 **마감일 오름차순** — 생성순과 무관하게
    /// 가장 빠른 마감이 위, 가장 먼 마감이 아래.
    @Test func scheduledFilterSortsByDueDateAscending() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                // due-soon은 나중에 추가됐지만(생성일이 더 늦음) 마감이 더 빠르다 → 위로 와야 한다.
                reminder(id: "due-soon", dueDate: now.addingTimeInterval(3600),
                         creationDate: now.addingTimeInterval(20), listID: "A"),
                reminder(id: "due-later", dueDate: now.addingTimeInterval(7200),
                         creationDate: now.addingTimeInterval(10), listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        viewModel.selectFilter(.scheduled)

        // 마감일 오름차순: 빠른 due-soon이 위.
        #expect(viewModel.visibleReminders.map(\.id) == ["due-soon", "due-later"])
    }

    /// 전체(.all) 화면 렌더링 경로인 allModeSections도 각 섹션을 생성순으로 정렬한다.
    /// 생성순과 "시간 없는 항목 먼저"가 상충하도록 데이터를 짜서, 진짜 생성순인지 가린다.
    @Test func allModeSectionsSortActiveByCreationOrder() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                // older: 먼저 추가됐지만 시간 지정 항목 — 구식 정렬이면 아래로 갔을 것.
                reminder(id: "older", dueDate: now.addingTimeInterval(3600), includesTime: true,
                         creationDate: now.addingTimeInterval(10), listID: "A"),
                // newer: 나중에 추가됐지만 시간 없음 — 구식 정렬이면 위로 갔을 것.
                reminder(id: "newer", creationDate: now.addingTimeInterval(20), listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        let sections = viewModel.allModeSections

        // 생성순: older가 먼저 추가됐으니 위 — 시간 지정 여부와 무관.
        #expect(sections[0].active.map(\.id) == ["older", "newer"])
    }

    /// `.all` 모드 섹션 그루핑 — lists 순서 보존, 각 섹션은 그 리스트의 미완료만.
    @Test func allModeSectionsGroupsByListPreservingOrder() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "a1", listID: "A"),
                reminder(id: "b1", listID: "B"),
                reminder(id: "a-done", isCompleted: true, listID: "A"),
            ]
        ))
        await viewModel.onAppear()

        let sections = viewModel.allModeSections

        #expect(sections.map(\.list.id) == ["A", "B"])
        #expect(sections[0].active.map(\.id) == ["a1"])
        #expect(sections[1].active.map(\.id) == ["b1"])
    }

    /// `.all` 모드 섹션 — `showsCompleted=true`면 각 섹션의 completed에 그 리스트의 완료 항목 포함.
    @Test func allModeSectionsIncludesCompletedWhenToggled() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "a1", listID: "A"),
                reminder(id: "a-done1", isCompleted: true, listID: "A"),
                reminder(id: "a-done2", isCompleted: true, listID: "A"),
                reminder(id: "b-done", isCompleted: true, listID: "B"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.showsCompleted = true

        let sections = viewModel.allModeSections

        #expect(sections[0].active.map(\.id) == ["a1"])
        #expect(Set(sections[0].completed.map(\.id)) == Set(["a-done1", "a-done2"]))
        #expect(sections[1].active.isEmpty)
        #expect(sections[1].completed.map(\.id) == ["b-done"])
    }

    /// `.all` 모드 섹션 — `showsCompleted=false`면 completed가 비어 있어야 한다(토글 OFF 동안 숨김).
    @Test func allModeSectionsHidesCompletedWhenToggleOff() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "a1", listID: "A"),
                reminder(id: "a-done", isCompleted: true, listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.showsCompleted = false

        let sections = viewModel.allModeSections

        #expect(sections[0].active.map(\.id) == ["a1"])
        #expect(sections[0].completed.isEmpty)
    }

    /// `.all` 모드 섹션 — 빈 리스트도 포함(섹션 헤더는 그려야 함).
    @Test func allModeSectionsIncludesEmptyLists() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [reminder(id: "a1", listID: "A")]
        ))
        await viewModel.onAppear()

        let sections = viewModel.allModeSections

        #expect(sections.count == 2)
        #expect(sections[1].active.isEmpty)
    }

    // MARK: - 섹션별 정렬 설정 (오늘·개별 리스트)

    /// 개별 리스트의 기본 정렬은 수동 — 저장된 수동 순서가 없으면 생성일 오래된 순으로 시드.
    @Test func listDefaultSortIsManualSeededByCreationOrder() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "b", creationDate: now.addingTimeInterval(20), listID: "A"),
                reminder(id: "a", creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "c", creationDate: now.addingTimeInterval(30), listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)  // 개별 리스트 스코프로 진입.

        #expect(viewModel.visibleReminders.map(\.id) == ["a", "b", "c"])
        #expect(viewModel.currentSortPreference == .default)
        #expect(viewModel.canSort)
    }

    /// 저장돼 있던 정렬 설정(마감일·이른 순)을 스코프 진입 시 읽어 적용한다. nil 마감은 맨 뒤.
    @Test func listAppliesPersistedDueDateAscending() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "late", dueDate: now.addingTimeInterval(7200), listID: "A"),
                reminder(id: "early", dueDate: now.addingTimeInterval(3600), listID: "A"),
                reminder(id: "nodue", listID: "A"),
            ],
            sortSettings: [
                "list:A": ReminderSortSettings(
                    preference: .init(field: .dueDate, direction: .ascending),
                    manualOrder: []
                )
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)

        #expect(viewModel.visibleReminders.map(\.id) == ["early", "late", "nodue"])
    }

    /// 정렬 기준=생성일·방향=최신 순을 고르면 최신 항목이 위로. 설정도 갱신된다.
    @Test func selectingCreationDateDescendingShowsNewestFirst() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "old", creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "new", creationDate: now.addingTimeInterval(20), listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)

        await viewModel.selectSortField(.creationDate)
        await viewModel.selectSortDirection(.descending)

        #expect(viewModel.visibleReminders.map(\.id) == ["new", "old"])
        #expect(viewModel.currentSortPreference.field == .creationDate)
        #expect(viewModel.currentSortPreference.direction == .descending)
    }

    /// 제목 정렬(가나다 오름차순) — 로케일 비교로 한글 가나다 순.
    @Test func titleAscendingSortsByLocalizedTitle() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "2", title: "바나나", listID: "A"),
                reminder(id: "1", title: "가지", listID: "A"),
                reminder(id: "3", title: "사과", listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)

        await viewModel.selectSortField(.title)

        #expect(viewModel.visibleReminders.map(\.id) == ["1", "2", "3"])
    }

    /// 드래그(재배열)하면 정렬 기준이 '수동'으로 바뀌고 그 순서가 저장된다.
    @Test func draggingSwitchesToManualAndAppliesNewOrder() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "a", creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "b", creationDate: now.addingTimeInterval(20), listID: "A"),
                reminder(id: "c", creationDate: now.addingTimeInterval(30), listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)
        // 기본 수동·생성 시드 → [a, b, c]. c(인덱스 2)를 맨 위로 끌어올린다.

        await viewModel.moveReminders(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(viewModel.visibleReminders.map(\.id) == ["c", "a", "b"])
        #expect(viewModel.currentSortPreference.field == .manual)
    }

    /// 마감일 정렬 중이라도 드래그하면 '수동'으로 전환되고 끌어놓은 순서가 유지된다.
    @Test func draggingWhileDueDateSortedConvertsToManual() async {
        let now = Date()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "early", dueDate: now.addingTimeInterval(3600), listID: "A"),
                reminder(id: "late", dueDate: now.addingTimeInterval(7200), listID: "A"),
            ],
            sortSettings: [
                "list:A": ReminderSortSettings(
                    preference: .init(field: .dueDate, direction: .ascending), manualOrder: []
                )
            ]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)
        // 마감일 오름차순 → [early, late]. late(인덱스 1)를 맨 위로.

        await viewModel.moveReminders(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        #expect(viewModel.currentSortPreference.field == .manual)
        #expect(viewModel.visibleReminders.map(\.id) == ["late", "early"])
    }

    /// 전체·예정에는 정렬 메뉴가 없다(canSort=false) — 이 두 모드는 고정 정렬.
    @Test func systemFiltersAllAndScheduledCannotSort() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        viewModel.selectFilter(.all)
        #expect(!viewModel.canSort)

        viewModel.selectFilter(.scheduled)
        #expect(!viewModel.canSort)
    }

    @Test func toggleFlipsCompletion() async {
        let target = reminder(id: "1", isCompleted: false, listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()

        await viewModel.toggle(target)

        #expect(viewModel.allReminders.first?.isCompleted == true)
    }

    @Test func addInsertsReminderIntoSelectedList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "새 미리알림")

        #expect(viewModel.visibleReminders.contains { $0.title == "새 미리알림" })
    }

    @Test func addWithBlankTitleSurfacesError() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "   ")

        #expect(viewModel.errorMessage != nil)
    }

    @Test func addStoresNotes() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.add(title: "장보기", notes: "우유 사기")

        #expect(viewModel.visibleReminders.first { $0.title == "장보기" }?.notes == "우유 사기")
    }

    @Test func updateStoresDueDate() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")]
        ))
        await viewModel.onAppear()
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.update(
            reminderID: "1", title: "마감 있는 일", notes: nil,
            dueDate: due, includesTime: true
        )

        let updated = viewModel.visibleReminders.first
        #expect(updated?.dueDate == due)
        #expect(updated?.includesTime == true)
    }

    @Test func updateChangesTitleAndNotes() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", title: "옛 제목", listID: "A")]
        ))
        await viewModel.onAppear()

        await viewModel.update(reminderID: "1", title: "새 제목", notes: "새 메모")

        #expect(viewModel.visibleReminders.first?.title == "새 제목")
        #expect(viewModel.visibleReminders.first?.notes == "새 메모")
    }

    @Test func addStoresDueDate() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()
        let due = Date(timeIntervalSince1970: 1_700_000_000)

        await viewModel.add(title: "마감", dueDate: due, includesTime: true)

        #expect(viewModel.visibleReminders.first { $0.title == "마감" }?.dueDate == due)
    }

    @Test func deleteRemovesReminder() async {
        let target = reminder(id: "1", listID: "A")
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA], reminders: [target]
        ))
        await viewModel.onAppear()

        await viewModel.delete(target)

        #expect(viewModel.visibleReminders.isEmpty)
    }

    // MARK: - List CRUD

    @Test func addListCreatesAndSelectsNewList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.addList(title: "사이드 프로젝트", colorHex: "#FF9500")

        #expect(viewModel.lists.contains { $0.title == "사이드 프로젝트" })
        // 새로 만든 리스트로 자동 전환.
        #expect(viewModel.selectedList?.title == "사이드 프로젝트")
    }

    @Test func addListWithBlankTitleSurfacesError() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()
        viewModel.select(listA)

        await viewModel.addList(title: "   ", colorHex: nil)

        #expect(viewModel.errorMessage != nil)
        // selected는 그대로.
        #expect(viewModel.selectedListID == "A")
    }

    @Test func updateListChangesTitleAndColor() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA]))
        await viewModel.onAppear()

        await viewModel.updateList(listID: "A", title: "새 이름", colorHex: "#34C759")

        let updated = viewModel.lists.first { $0.id == "A" }
        #expect(updated?.title == "새 이름")
        #expect(updated?.colorHex == "#34C759")
    }

    @Test func deleteListRemovesItAndMovesSelection() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [reminder(id: "1", listID: "A")]
        ))
        await viewModel.onAppear()
        viewModel.select(listA)  // A 리스트를 선택한 상태에서 그 리스트를 삭제.

        await viewModel.deleteList(listID: "A")

        #expect(viewModel.lists.map(\.id) == ["B"])
        // 안 있던 항목도 함께 사라짐.
        #expect(viewModel.allReminders.isEmpty)
        // selected는 남은 첫 리스트로 옮겨감.
        #expect(viewModel.selectedListID == "B")
    }

    @Test func deleteListKeepsSelectionWhenOtherListDeleted() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB]
        ))
        await viewModel.onAppear()
        viewModel.select(listB)  // 현재 B 선택 중.

        await viewModel.deleteList(listID: "A")

        // 다른 리스트 삭제는 selection에 영향 없음.
        #expect(viewModel.selectedListID == "B")
    }

    // MARK: - Live Activity 갱신

    @Test func completingReminderRefreshesActiveLiveActivity() async {
        let recording = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A"), reminder(id: "2", listID: "A")],
            liveActivityService: recording
        ))
        await viewModel.onAppear()

        await viewModel.toggleLiveActivity(listTitle: "회사")  // 시작 — 1번째 호출
        #expect(viewModel.liveActivityActive)

        await viewModel.toggle(reminder(id: "1", listID: "A")) // 완료 → 활성 LA 갱신

        // 시작 1 + 완료 후 갱신 1 = 최소 2회. 갱신분의 항목엔 완료된 "1"이 빠져야 한다.
        let calls = await recording.startReminderCalls
        #expect(calls.count >= 2)
        #expect(calls.last?.items.map(\.id) == ["2"])
    }

    @Test func completingReminderWithInactiveLiveActivityDoesNotRefresh() async {
        let recording = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")],
            liveActivityService: recording
        ))
        await viewModel.onAppear()

        await viewModel.toggle(reminder(id: "1", listID: "A")) // LA 비활성 — 갱신 없어야

        #expect(await recording.startReminderCalls.isEmpty)
    }

    // MARK: - 스냅샷 캐시 + 프리페치

    /// 캐시가 있으면 fetch를 기다리지 않고 즉시 페인트하고, 스피너를 띄우지 않는다.
    /// (조용한 최신화가 끝나면 fetch 결과로 대체된다.)
    @Test func cachedSnapshotPaintsImmediatelyWithoutSpinner() async throws {
        let cached = reminder(id: "cached", title: "캐시 항목", listID: "A")
        let fresh = reminder(id: "fresh", title: "실제 항목", listID: "A")
        let cache = InMemorySnapshotCacheRepository(
            remindersSnapshot: RemindersSnapshot(lists: [listA], reminders: [cached])
        )
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA], reminders: [fresh])
        let repo = GatedRemindersRepository(base)
        await repo.closeGate()   // 조용한 최신화 fetch를 붙잡아 "캐시만 그려진" 순간을 관측.
        var deps = makeDependencies(remindersRepository: repo)
        deps.loadRemindersSnapshot = LoadRemindersSnapshotUseCase(repository: cache)
        deps.saveRemindersSnapshot = SaveRemindersSnapshotUseCase(repository: cache)
        let viewModel = ReminderViewModel(dependencies: deps)

        let appearTask = Task { await viewModel.onAppear() }
        // 캐시 페인트가 일어날 때까지 (bounded — 최대 ~1s).
        var painted = false
        for _ in 0..<200 {
            if viewModel.allReminders == [cached] { painted = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(painted)
        #expect(viewModel.lists == [listA])
        #expect(viewModel.isLoading == false)   // 캐시 경로는 스피너 금지.

        await repo.releaseFetch()
        await appearTask.value
        #expect(viewModel.allReminders == [fresh])   // 최신화 완료 — fetch 결과로 대체.
    }

    /// 캐시가 없으면 기존 경로 그대로 — 첫 적재 동안 스피너를 띄운다.
    @Test func firstLoadWithoutCacheShowsSpinner() async throws {
        let base = InMemoryRemindersRepository(access: .granted, lists: [listA])
        let repo = GatedRemindersRepository(base)
        await repo.closeGate()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))

        let appearTask = Task { await viewModel.onAppear() }
        var waiting = false
        for _ in 0..<200 {
            if await repo.isFetchWaiting { waiting = true; break }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(waiting)
        #expect(viewModel.isLoading == true)

        await repo.releaseFetch()
        await appearTask.value
        #expect(viewModel.isLoading == false)
    }

    /// 적재가 성공하면 스냅샷을 저장한다 — 다음 실행의 첫 페인트 재료.
    @Test func reloadSavesSnapshotForNextLaunch() async {
        let cache = InMemorySnapshotCacheRepository()
        let item = reminder(id: "1", listID: "A")
        var deps = makeDependencies(access: .granted, lists: [listA], reminders: [item])
        deps.loadRemindersSnapshot = LoadRemindersSnapshotUseCase(repository: cache)
        deps.saveRemindersSnapshot = SaveRemindersSnapshotUseCase(repository: cache)
        let viewModel = ReminderViewModel(dependencies: deps)

        await viewModel.onAppear()

        #expect(await cache.remindersSnapshot == RemindersSnapshot(lists: [listA], reminders: [item]))
    }

    /// 프리페치 — 이미 권한이 허용된 경우에만 첫 적재를 미리 수행한다(탭 진입 전 스피너 제거).
    @Test func prefetchLoadsWhenAccessAlreadyGranted() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .granted, lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        ))

        await viewModel.prefetch()

        #expect(viewModel.access == .granted)
        #expect(viewModel.allReminders.count == 1)
    }

    /// 프리페치는 권한 프롬프트를 절대 유발하지 않는다 — 미결정이면 아무것도 하지 않는다.
    /// (InMemory 구현은 requestAccess가 미결정→허용으로 바꾸므로, 상태가 미결정 그대로면
    /// 프롬프트 경로를 타지 않았다는 증거다.)
    @Test func prefetchDoesNothingWhenAccessNotDetermined() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .notDetermined, lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        ))

        await viewModel.prefetch()

        #expect(viewModel.access == .notDetermined)
        #expect(viewModel.allReminders.isEmpty)
    }

    /// 프리페치가 끝난 뒤 탭 진입(onAppear)은 fetch를 반복하지 않는다 — 첫 적재는 한 번뿐.
    @Test func onAppearAfterPrefetchDoesNotRefetch() async {
        let base = InMemoryRemindersRepository(
            access: .granted, lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )
        let repo = GatedRemindersRepository(base)
        let viewModel = ReminderViewModel(dependencies: makeDependencies(remindersRepository: repo))

        await viewModel.prefetch()
        let afterPrefetch = await repo.fetchCount
        await viewModel.onAppear()

        #expect(afterPrefetch == 1)
        #expect(await repo.fetchCount == afterPrefetch)
        #expect(viewModel.allReminders.count == 1)
    }

    // MARK: - 전체 탭 드래그 앤 드랍

    private let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    /// 전체 탭 섹션 내부도 각 리스트의 저장된 정렬 설정(수동 순서)을 따른다 —
    /// 생성순 고정이던 기존 동작에서 전환(설정 없으면 .default = 생성순 시드라 동일).
    @Test func allModeSectionsRespectPerListManualOrder() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
            ],
            sortSettings: ["list:A": ReminderSortSettings(
                preference: .init(field: .manual, direction: .ascending),
                manualOrder: ["2", "1"]
            )]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        #expect(viewModel.allModeSections.first?.active.map(\.id) == ["2", "1"])
    }

    /// 전체 탭 섹션 간 드래그 — 항목이 실제로 다른 리스트로 이동하고, 드랍 위치가
    /// 대상 리스트의 수동 순서에 반영된다.
    @Test func moveAcrossAllModeSectionsMovesListAndKeepsDropPosition() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
                reminder(id: "3", creationDate: baseDate.addingTimeInterval(120), listID: "B"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        // A의 "1"을 B 섹션 맨 앞(offset 0)에 드랍.
        await viewModel.moveReminder(reminderID: "1", toListID: "B", toOffset: 0)

        let sections = viewModel.allModeSections
        #expect(sections.first { $0.list.id == "A" }?.active.map(\.id) == ["2"])
        #expect(sections.first { $0.list.id == "B" }?.active.map(\.id) == ["1", "3"])
        #expect(viewModel.allReminders.first { $0.id == "1" }?.listID == "B")
    }

    /// `.all` 모드 평탄화 — 리스트마다 헤더 → 미완료 항목 → (완료) → 입력 슬롯 → 디바이더 순.
    /// 단일 ForEach + .onMove로 섹션 간 드래그를 가능하게 하는 행 구조.
    @Test func allModeRowsFlattenSectionsInOrder() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "B"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        #expect(viewModel.allModeRows.map(\.id) == [
            "header:A", "reminder:1", "input:A", "divider:A",
            "header:B", "reminder:2", "input:B", "divider:B",
        ])
    }

    /// 평탄 인덱스 onMove — 같은 섹션 안(입력 슬롯 직전 = 맨 뒤)으로 옮기면 수동 재배열.
    @Test func moveAllModeRowWithinSameSectionReorders() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
                reminder(id: "3", creationDate: baseDate.addingTimeInterval(120), listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        // rows: [header:A, r1, r2, r3, input:A, divider:A] — r1(인덱스 1)을 인덱스 4(맨 뒤)로.
        await viewModel.moveAllModeRow(fromOffsets: IndexSet(integer: 1), toOffset: 4)

        #expect(viewModel.allModeSections.first?.active.map(\.id) == ["2", "3", "1"])
    }

    /// 평탄 인덱스 onMove — 다른 섹션 헤더 바로 아래로 옮기면 그 리스트 맨 앞으로 이동.
    @Test func moveAllModeRowAcrossSectionsMovesList() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
                reminder(id: "3", creationDate: baseDate.addingTimeInterval(120), listID: "B"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        // rows: [header:A, r1, r2, input:A, divider:A, header:B, r3, input:B, divider:B]
        // r1(인덱스 1)을 인덱스 6(header:B 바로 아래, r3 앞)으로.
        await viewModel.moveAllModeRow(fromOffsets: IndexSet(integer: 1), toOffset: 6)

        let sections = viewModel.allModeSections
        #expect(sections.first { $0.list.id == "A" }?.active.map(\.id) == ["2"])
        #expect(sections.first { $0.list.id == "B" }?.active.map(\.id) == ["1", "3"])
        #expect(viewModel.allReminders.first { $0.id == "1" }?.listID == "B")
    }

    /// 완료 항목 표시가 켜져 있으면 완료 행이 미완료와 입력 슬롯 사이에 끼어 평탄화된다.
    @Test func allModeRowsIncludeCompletedRowsWhenShown() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", isCompleted: true, creationDate: baseDate.addingTimeInterval(60), listID: "A"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)
        viewModel.showsCompleted = true

        #expect(viewModel.allModeRows.map(\.id) == [
            "header:A", "reminder:1", "completed:2", "input:A", "divider:A",
        ])
    }

    /// moveDisabled 없이 헤더·입력 행도 들 수는 있으므로, 비항목 행이 소스인 onMove는
    /// 아무것도 바꾸지 않아야 한다 — 유일한 방어선인 소스 가드 검증.
    @Test func moveAllModeRowIgnoresNonReminderSource() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "B"),
            ]
        ))
        await viewModel.onAppear()
        viewModel.selectFilter(.all)
        let before = viewModel.allModeRows.map(\.id)

        // 인덱스 0 = header:A, 인덱스 2 = input:A — 둘 다 no-op이어야 한다.
        await viewModel.moveAllModeRow(fromOffsets: IndexSet(integer: 0), toOffset: 6)
        await viewModel.moveAllModeRow(fromOffsets: IndexSet(integer: 2), toOffset: 6)

        #expect(viewModel.allModeRows.map(\.id) == before)
    }

    /// 평탄 인덱스 → (리스트, 섹션 내 위치) 해석의 경계값들.
    @Test func allModeDropTargetResolvesBoundaryDestinations() {
        let a = ReminderList(id: "A", title: "A", colorHex: nil)
        let b = ReminderList(id: "B", title: "B", colorHex: nil)
        let r1 = reminder(id: "1", listID: "A")
        let r2 = reminder(id: "2", isCompleted: true, listID: "A")
        let r3 = reminder(id: "3", listID: "B")
        let rows: [ReminderViewModel.AllModeRow] = [
            .header(a), .reminder(r1), .completed(r2), .inputSlot(listID: "A"), .divider(listID: "A"),
            .header(b), .reminder(r3), .inputSlot(listID: "B"), .divider(listID: "B"),
        ]

        func target(_ destination: Int) -> (listID: String, offset: Int)? {
            ReminderViewModel.allModeDropTarget(rows: rows, destination: destination)
        }
        // 모든 헤더보다 위 → 첫 리스트 맨 앞.
        #expect(target(0)?.listID == "A"); #expect(target(0)?.offset == 0)
        // 다음 섹션 헤더 자리(위쪽 틈) → 이전 리스트 맨 뒤.
        #expect(target(5)?.listID == "A"); #expect(target(5)?.offset == 1)
        // 완료 행 사이/뒤 → 그 리스트 미완료 맨 뒤(완료 행은 위치 계산에서 제외).
        #expect(target(3)?.listID == "A"); #expect(target(3)?.offset == 1)
        // 헤더 바로 아래 → 그 리스트 맨 앞.
        #expect(target(6)?.listID == "B"); #expect(target(6)?.offset == 0)
        // 목록 끝(마지막 디바이더 뒤) → 마지막 리스트 맨 뒤.
        #expect(target(rows.count)?.listID == "B"); #expect(target(rows.count)?.offset == 1)
    }

    /// 섹션 간 이동 시 원본 리스트의 수동 순서에서 그 항목이 제거되어 영속된다.
    @Test func moveAcrossSectionsRemovesIDFromSourceManualOrder() async {
        let sortRepository = InMemoryReminderSortRepository(storage: [
            "list:A": ReminderSortSettings(
                preference: .init(field: .manual, direction: .ascending),
                manualOrder: ["2", "1"]
            ),
        ])
        var deps = makeDependencies(
            lists: [listA, listB],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
            ]
        )
        deps.fetchReminderSortSettings = FetchReminderSortSettingsUseCase(repository: sortRepository)
        deps.saveReminderSortSettings = SaveReminderSortSettingsUseCase(repository: sortRepository)
        let viewModel = ReminderViewModel(dependencies: deps)
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        await viewModel.moveReminder(reminderID: "1", toListID: "B", toOffset: 0)

        #expect(await sortRepository.fetch(scope: "list:A").manualOrder == ["2"])
        #expect(await sortRepository.fetch(scope: "list:B").manualOrder == ["1"])
    }

    /// 같은 섹션 안에 드랍한 경우 — 리스트 이동 없이 수동 재배열로 처리한다.
    /// (.onInsert 드랍 경로가 섹션 내 재배열까지 담당하므로: offset은 원본 행이 아직
    /// 제거되지 않은 상태의 삽입 위치 — 뒤로 옮길 땐 1 보정된다.)
    @Test func dropWithinSameSectionReordersManually() async {
        let sortRepository = InMemoryReminderSortRepository()
        var deps = makeDependencies(
            lists: [listA],
            reminders: [
                reminder(id: "1", creationDate: baseDate, listID: "A"),
                reminder(id: "2", creationDate: baseDate.addingTimeInterval(60), listID: "A"),
                reminder(id: "3", creationDate: baseDate.addingTimeInterval(120), listID: "A"),
            ]
        )
        deps.fetchReminderSortSettings = FetchReminderSortSettingsUseCase(repository: sortRepository)
        deps.saveReminderSortSettings = SaveReminderSortSettingsUseCase(repository: sortRepository)
        let viewModel = ReminderViewModel(dependencies: deps)
        await viewModel.onAppear()
        viewModel.selectFilter(.all)

        // "1"을 맨 뒤(offset 3 — 제거 전 기준)에 드랍.
        await viewModel.moveReminder(reminderID: "1", toListID: "A", toOffset: 3)

        #expect(viewModel.allModeSections.first?.active.map(\.id) == ["2", "3", "1"])
        let saved = await sortRepository.fetch(scope: "list:A")
        #expect(saved.preference.field == .manual)
        #expect(saved.manualOrder == ["2", "3", "1"])
    }

    // MARK: - 애널리틱스

    /// 스파이를 배선한 ViewModel — 애널리틱스 테스트 공통 조립.
    private func makeAnalyticsViewModel(
        lists: [ReminderList],
        reminders: [Reminder] = []
    ) async -> (ReminderViewModel, SpyAnalyticsService) {
        let analytics = SpyAnalyticsService()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: lists, reminders: reminders, analytics: analytics
        ))
        await viewModel.onAppear()
        return (viewModel, analytics)
    }

    /// 첫 적재·초기 selection 해석 같은 프로그램적 경로는 아무 이벤트도 남기지 않는다.
    @Test func initialLoadLogsNoAnalyticsEvents() async {
        let (_, analytics) = await makeAnalyticsViewModel(
            lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )

        #expect(analytics.events.isEmpty)
    }

    /// 완료 방향 토글은 `.reminderCompleted(source: "app")` — 기존 로깅 회귀 방지.
    @Test func completingReminderLogsCompletedWithAppSource() async {
        let target = reminder(id: "1", isCompleted: false, listID: "A")
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA], reminders: [target])

        await viewModel.toggle(target)

        #expect(analytics.events == [.reminderCompleted(source: "app")])
    }

    /// 체크 해제(완료 → 미완료) 방향은 `.reminderUncompleted`.
    @Test func uncompletingReminderLogsUncompleted() async {
        let target = reminder(id: "1", isCompleted: true, listID: "A")
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA], reminders: [target])

        await viewModel.toggle(target)

        #expect(analytics.events == [.reminderUncompleted])
    }

    /// add 성공 시 `.reminderCreated` — 기존 로깅 회귀 방지.
    @Test func addingReminderLogsCreated() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        await viewModel.add(title: "새 미리알림")

        #expect(analytics.events == [.reminderCreated])
    }

    /// update 성공 시 `.reminderUpdated`.
    @Test func updatingReminderLogsUpdated() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )

        await viewModel.update(reminderID: "1", title: "새 제목", notes: nil)

        #expect(analytics.events == [.reminderUpdated])
    }

    /// delete 성공 시 `.reminderDeleted`.
    @Test func deletingReminderLogsDeleted() async {
        let target = reminder(id: "1", listID: "A")
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA], reminders: [target])

        await viewModel.delete(target)

        #expect(analytics.events == [.reminderDeleted])
    }

    /// 단일 리스트 드래그 재배열은 `.reminderReordered` — 정렬 변경 이벤트가 아니다.
    @Test func draggingWithinListLogsReordered() async {
        let now = Date()
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA],
            reminders: [
                reminder(id: "a", creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "b", creationDate: now.addingTimeInterval(20), listID: "A"),
            ]
        )
        viewModel.select(listA)

        await viewModel.moveReminders(fromOffsets: IndexSet(integer: 1), toOffset: 0)

        #expect(analytics.events == [.reminderScopeSelected(scope: "list"), .reminderReordered])
    }

    /// 스코프 없는 모드(전체)에선 moveReminders가 no-op — 이벤트도 없어야 한다.
    @Test func draggingWithoutSortScopeLogsNothing() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )
        viewModel.selectFilter(.all)

        await viewModel.moveReminders(fromOffsets: IndexSet(integer: 0), toOffset: 1)

        #expect(analytics.events == [.reminderScopeSelected(scope: "all")])
    }

    /// 전체 모드 섹션 간 이동은 `.reminderMovedToList`.
    @Test func movingReminderAcrossListsLogsMovedToList() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA, listB],
            reminders: [reminder(id: "1", listID: "A")]
        )
        viewModel.selectFilter(.all)

        await viewModel.moveReminder(reminderID: "1", toListID: "B", toOffset: 0)

        #expect(analytics.events == [.reminderScopeSelected(scope: "all"), .reminderMovedToList])
    }

    /// 전체 모드에서 같은 섹션 안 드랍은 이동이 아니라 재배열 — `.reminderReordered`.
    @Test func droppingWithinSameSectionLogsReordered() async {
        let now = Date()
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA],
            reminders: [
                reminder(id: "1", creationDate: now.addingTimeInterval(10), listID: "A"),
                reminder(id: "2", creationDate: now.addingTimeInterval(20), listID: "A"),
            ]
        )
        viewModel.selectFilter(.all)

        await viewModel.moveReminder(reminderID: "1", toListID: "A", toOffset: 2)

        #expect(analytics.events == [.reminderScopeSelected(scope: "all"), .reminderReordered])
    }

    /// 정렬 기준 변경 — 결과 기준/방향의 rawValue가 파라미터로 남는다.
    @Test func changingSortFieldLogsSortChanged() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )
        viewModel.select(listA)

        await viewModel.selectSortField(.dueDate)

        #expect(analytics.events == [
            .reminderScopeSelected(scope: "list"),
            .reminderSortChanged(key: "dueDate", order: "ascending"),
        ])
    }

    /// 정렬 방향 변경도 같은 이벤트 — 바뀐 방향이 order로 남는다.
    @Test func changingSortDirectionLogsSortChanged() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(
            lists: [listA], reminders: [reminder(id: "1", listID: "A")]
        )
        viewModel.select(listA)

        await viewModel.selectSortDirection(.descending)

        #expect(analytics.events == [
            .reminderScopeSelected(scope: "list"),
            .reminderSortChanged(key: "manual", order: "descending"),
        ])
    }

    /// 고정 정렬 스코프(예정)에선 정렬 변경이 no-op — 이벤트도 없다.
    @Test func changingSortInFixedScopeLogsNothing() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])
        viewModel.selectFilter(.scheduled)

        await viewModel.selectSortField(.dueDate)

        #expect(analytics.events == [.reminderScopeSelected(scope: "scheduled")])
    }

    /// 완료된 항목 보기 토글 — 켤 때 on: true, 끌 때 on: false.
    @Test func togglingShowsCompletedLogsState() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        viewModel.toggleShowsCompleted()
        #expect(viewModel.showsCompleted == true)
        viewModel.toggleShowsCompleted()
        #expect(viewModel.showsCompleted == false)

        #expect(analytics.events == [
            .reminderShowCompletedToggled(on: true),
            .reminderShowCompletedToggled(on: false),
        ])
    }

    /// 리스트 생성 성공 시 `.reminderListCreated`. (생성 직후 자동 전환은 프로그램적 selection —
    /// scope 이벤트를 남기지 않는다.)
    @Test func addingListLogsListCreated() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        await viewModel.addList(title: "사이드", colorHex: nil)

        #expect(analytics.events == [.reminderListCreated])
    }

    /// 리스트 생성 실패(빈 제목)엔 이벤트가 없다.
    @Test func failedAddListLogsNothing() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        await viewModel.addList(title: "   ", colorHex: nil)

        #expect(analytics.events.isEmpty)
    }

    /// 리스트 수정 성공 시 `.reminderListUpdated`.
    @Test func updatingListLogsListUpdated() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        await viewModel.updateList(listID: "A", title: "새 이름", colorHex: nil)

        #expect(analytics.events == [.reminderListUpdated])
    }

    /// 리스트 삭제 성공 시 `.reminderListDeleted`.
    @Test func deletingListLogsListDeleted() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA, listB])

        await viewModel.deleteList(listID: "B")

        #expect(analytics.events == [.reminderListDeleted])
    }

    /// 사용자 리스트 선택은 scope "list"로 남는다(개별 리스트 id는 수집하지 않는다).
    @Test func selectingListLogsScopeSelected() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA, listB])

        viewModel.select(listB)

        #expect(analytics.events == [.reminderScopeSelected(scope: "list")])
    }

    /// 시스템 필터 선택은 필터 식별자(rawValue)가 scope로 남는다.
    @Test func selectingSystemFilterLogsScopeIdentifier() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        viewModel.selectFilter(.today)

        #expect(analytics.events == [.reminderScopeSelected(scope: "today")])
    }

    /// 좌상단 "미리 알림" 버튼 — 외부 앱 열기 이벤트(뷰가 openURL 직전에 호출).
    @Test func openingRemindersAppLogsExternalAppOpened() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        viewModel.logRemindersAppOpened()

        #expect(analytics.events == [.externalAppOpened(app: "reminders")])
    }

    /// 접근 거부 화면의 "설정 열기" — 권한 설정 이동 이벤트.
    @Test func openingPermissionSettingsLogsReminderKind() async {
        let (viewModel, analytics) = await makeAnalyticsViewModel(lists: [listA])

        viewModel.logPermissionSettingsOpened()

        #expect(analytics.events == [.permissionSettingsOpened(kind: "reminder")])
    }
}

// MARK: - 애널리틱스 스파이

private final class SpyAnalyticsService: AnalyticsService, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func log(name: String, parameters: [String: String]) {}
}

/// `fetchReminders`를 게이트로 붙잡을 수 있는 리포지토리 더블 — 나머지는 InMemory에 위임한다.
/// 게이트를 닫으면 다음 fetchReminders가 `releaseFetch()`까지 대기해, reload가 "진행 중"인
/// 순간을 테스트가 결정론적으로 관측할 수 있다. 변경 신호·데이터는 모두 base 인스턴스가 소유.
/// 테스트용 가변 시계 — 억제 창 경계를 결정론적으로 넘나들기 위해 `now`를 직접 조작한다.
@MainActor
private final class TestClock {
    var now: Date
    init(_ start: Date) { now = start }
}

private actor GatedRemindersRepository: RemindersRepository {
    private let base: InMemoryRemindersRepository
    private var gateClosed = false
    private(set) var isFetchWaiting = false
    private(set) var fetchCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    // update 쓰기를 붙잡는 게이트 — "저장소 반환 전 선반영" 계약의 관측점.
    private var updateGateClosed = false
    private(set) var isUpdateWaiting = false
    private var updateWaiters: [CheckedContinuation<Void, Never>] = []

    init(_ base: InMemoryRemindersRepository) { self.base = base }

    func closeGate() { gateClosed = true }
    func releaseFetch() {
        gateClosed = false
        isFetchWaiting = false
        for waiter in waiters { waiter.resume() }
        waiters = []
    }
    /// 붙잡힌 fetch 중 **가장 먼저 진입한 하나만** 풀어준다 — 스테일 착지 순서를 결정적으로
    /// 재현하기 위함(게이트는 닫힌 채 유지).
    func releaseNextFetch() {
        guard !waiters.isEmpty else { return }
        waiters.removeFirst().resume()
        isFetchWaiting = !waiters.isEmpty
    }
    func closeUpdateGate() { updateGateClosed = true }
    func releaseUpdate() {
        updateGateClosed = false
        isUpdateWaiting = false
        for waiter in updateWaiters { waiter.resume() }
        updateWaiters = []
    }

    nonisolated func changes() -> AsyncStream<Void> { base.changes() }
    func requestAccess() async -> RemindersAccess { await base.requestAccess() }
    func fetchLists() async throws -> [ReminderList] { try await base.fetchLists() }
    func fetchReminders() async throws -> [Reminder] {
        fetchCount += 1
        // 실제 EventKit처럼 **호출 시점의 상태**를 스냅샷으로 뜬 뒤 지연시킨다 — 게이트에
        // 붙잡힌 동안 일어난 쓰기는 이 결과에 반영되지 않아, "오래된 fetch가 늦게 착지"하는
        // 스테일 시나리오를 재현할 수 있다.
        let snapshot = try await base.fetchReminders()
        if gateClosed {
            isFetchWaiting = true
            await withCheckedContinuation { waiters.append($0) }
        }
        return snapshot
    }
    func setCompleted(_ completed: Bool, reminderID: String) async throws {
        try await base.setCompleted(completed, reminderID: reminderID)
    }
    @discardableResult
    func addReminder(
        title: String, notes: String?, dueDate: Date?, includesTime: Bool,
        recurrence: RecurrenceRule?, toListID listID: String
    ) async throws -> Reminder {
        try await base.addReminder(
            title: title, notes: notes, dueDate: dueDate, includesTime: includesTime,
            recurrence: recurrence, toListID: listID
        )
    }
    @discardableResult
    func updateReminder(
        reminderID: String, title: String, notes: String?, dueDate: Date?, includesTime: Bool,
        recurrence: RecurrenceRule?
    ) async throws -> Reminder {
        if updateGateClosed {
            isUpdateWaiting = true
            await withCheckedContinuation { updateWaiters.append($0) }
        }
        return try await base.updateReminder(
            reminderID: reminderID, title: title, notes: notes, dueDate: dueDate,
            includesTime: includesTime, recurrence: recurrence
        )
    }
    func deleteReminder(reminderID: String) async throws { try await base.deleteReminder(reminderID: reminderID) }
    func moveReminder(reminderID: String, toListID listID: String) async throws {
        try await base.moveReminder(reminderID: reminderID, toListID: listID)
    }
    func addList(title: String, colorHex: String?) async throws -> String {
        try await base.addList(title: title, colorHex: colorHex)
    }
    func updateList(listID: String, title: String, colorHex: String?) async throws {
        try await base.updateList(listID: listID, title: title, colorHex: colorHex)
    }
    func deleteList(listID: String) async throws { try await base.deleteList(listID: listID) }
}

/// 시작/갱신 호출을 기록하는 LA 더블. `isEnabled = true`라 ViewModel이 활성으로 전환된다.
private actor RecordingReminderLiveActivity: LiveActivityService {
    var isEnabled: Bool { true }
    private(set) var startReminderCalls: [(items: [LiveReminderItem], remaining: Int)] = []

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {
        startReminderCalls.append((items, remaining))
    }
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int, weekEventDots: [LiveDayEventDots], showsCalendarOverride: Bool?) async throws {}
    func endSchedule() async {}
    func endSamples() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {}
    func endMemo() async {}
    func sync() async {}
    func refreshLayout() async {}
}
