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
        liveActivityService: any LiveActivityService = DisabledLiveActivityService()
    ) -> Dependencies {
        let remindersRepository = InMemoryRemindersRepository(
            access: access, lists: lists, reminders: reminders
        )
        let reminderSortRepository = InMemoryReminderSortRepository(storage: sortSettings)
        let itemRepository = InMemoryItemRepository()
        let eventsRepository = InMemoryEventsRepository(access: .granted)
        let focusSessionsRepository = InMemoryFocusSessionsRepository()
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
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepository),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusSessionsRepository),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusSessionsRepository),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusSessionsRepository),
            startReminderLiveActivity: StartReminderLiveActivityUseCase(service: liveActivityService),
            endReminderLiveActivity: EndReminderLiveActivityUseCase(service: liveActivityService),
            startScheduleLiveActivity: StartScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            endScheduleLiveActivity: EndScheduleLiveActivityUseCase(service: DisabledLiveActivityService()),
            fetchMemo: FetchMemoUseCase(repository: InMemoryMemoRepository()),
            saveMemo: SaveMemoUseCase(repository: InMemoryMemoRepository()),
            startMemoLiveActivity: StartMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            endMemoLiveActivity: EndMemoLiveActivityUseCase(service: DisabledLiveActivityService()),
            syncLiveActivities: SyncLiveActivitiesUseCase(service: DisabledLiveActivityService()),
            refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase(service: DisabledLiveActivityService()),
            consumeLiveActivation: ConsumeLiveActivationUseCase(repository: InMemoryLiveActivationQuotaRepository()),
            fetchAppSettings: FetchAppSettingsUseCase(repository: InMemoryAppSettingsRepository()),
            saveAppSettings: SaveAppSettingsUseCase(repository: InMemoryAppSettingsRepository())
        )
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

    /// 항상 표시 자동 게시 — 권한이 있으면 현재 선택 스냅샷으로 LA를 시작한다(쿼터 미소비).
    @Test func alwaysOnStartsReminderLiveActivity() async throws {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            lists: [listA],
            reminders: [reminder(id: "1", listID: "A")],
            liveActivityService: service
        ))

        await viewModel.startAlwaysOnLiveActivity()

        #expect(viewModel.liveActivityActive == true)
        #expect(await service.startReminderCalls.count == 1)
    }

    /// 권한이 거부돼 있으면 자동 게시하지 않는다.
    @Test func alwaysOnSkipsWhenAccessDenied() async {
        let service = RecordingReminderLiveActivity()
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .denied,
            liveActivityService: service
        ))

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
            observeEventsChanges: ObserveEventsChangesUseCase(repository: eventsRepo),
            fetchFocusSessions: FetchFocusSessionsUseCase(repository: focusRepo),
            saveFocusSessions: SaveFocusSessionsUseCase(repository: focusRepo),
            fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase(repository: focusRepo),
            saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase(repository: focusRepo),
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
            toListID: listA.id
        )
        await repo.emitChange()
        // observe task가 신호를 처리할 시간 — Task hop이 끝나도록 짧게 yield.
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(viewModel.allReminders.contains { $0.title == "외부 추가" })
    }

    @Test func onAppearWithDeniedAccessLoadsNothing() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(
            access: .denied, lists: [listA]
        ))

        await viewModel.onAppear()

        #expect(viewModel.access == .denied)
        #expect(viewModel.lists.isEmpty)
    }

    @Test func reloadSelectsFirstListByDefault() async {
        let viewModel = ReminderViewModel(dependencies: makeDependencies(lists: [listA, listB]))

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

    /// 시스템 필터에서 add() — 이름이 "미리 알림"인 리스트가 있으면 거기로 저장.
    @Test func addInSystemFilterUsesNamedDefaultList() async {
        let defaultList = ReminderList(id: "DEF", title: "미리 알림", colorHex: nil)
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
        // 자동 selection은 .list("A"). 그래도 toListID="B"가 우선.

        await viewModel.add(title: "B 섹션 입력", toListID: "B")

        let added = viewModel.allReminders.first { $0.title == "B 섹션 입력" }
        #expect(added?.listID == "B")
    }

    /// 시스템 필터에서 add() — "미리 알림" 이름 매칭이 없으면 `lists.first`로 fallback.
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
        await viewModel.onAppear()  // .list("A") 자동 selection.

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
        // 첫 진입은 A 선택.

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
}

/// 시작/갱신 호출을 기록하는 LA 더블. `isEnabled = true`라 ViewModel이 활성으로 전환된다.
private actor RecordingReminderLiveActivity: LiveActivityService {
    var isEnabled: Bool { true }
    private(set) var startReminderCalls: [(items: [LiveReminderItem], remaining: Int)] = []

    func startReminder(listTitle: String, items: [LiveReminderItem], remaining: Int, todayCount: Int) async throws {
        startReminderCalls.append((items, remaining))
    }
    func endReminder() async {}
    func startSchedule(days: [LiveScheduleDay], todayCount: Int) async throws {}
    func endSchedule() async {}
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws {}
    func endMemo() async {}
    func sync() async {}
    func refreshLayout() async {}
}
