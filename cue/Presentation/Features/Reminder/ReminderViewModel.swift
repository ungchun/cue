//
//  ReminderViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 미리알림 탭의 상태 + 동작. UseCase에만 의존하며 SwiftUI를 import하지 않는다.
@MainActor
@Observable
final class ReminderViewModel {
    private let requestAccessUseCase: RequestRemindersAccessUseCase
    private let fetchListsUseCase: FetchReminderListsUseCase
    private let fetchRemindersUseCase: FetchRemindersUseCase
    private let toggleCompletionUseCase: ToggleReminderCompletionUseCase
    private let addReminderUseCase: AddReminderUseCase
    private let updateReminderUseCase: UpdateReminderUseCase
    private let deleteReminderUseCase: DeleteReminderUseCase
    private let addReminderListUseCase: AddReminderListUseCase
    private let updateReminderListUseCase: UpdateReminderListUseCase
    private let deleteReminderListUseCase: DeleteReminderListUseCase
    private let observeChangesUseCase: ObserveRemindersChangesUseCase
    private let fetchSortSettingsUseCase: FetchReminderSortSettingsUseCase
    private let saveSortSettingsUseCase: SaveReminderSortSettingsUseCase
    private let startLiveActivityUseCase: StartReminderLiveActivityUseCase
    private let endLiveActivityUseCase: EndReminderLiveActivityUseCase
    private let consumeLiveActivation: ConsumeLiveActivationUseCase

    private(set) var access: RemindersAccess = .notDetermined
    private(set) var lists: [ReminderList] = []
    private(set) var allReminders: [Reminder] = []
    private(set) var isLoading = false
    /// 첫 데이터 적재가 끝났는지. `onAppear`가 탭 전환마다 재호출되더라도 두 번째
    /// 이상은 fetch를 건너뛴다 — 외부(미리 알림 앱)에서 실제 변경이 발생하면 그때만
    /// `observeTask`의 stream이 신호를 보내 reload가 호출되어 인디케이터 깜박임이 사라진다.
    private var hasLoaded = false
    /// 외부 변경 신호 스트림 구독. ViewModel 생애 동안 유지되며 신호가 올 때마다 reload.
    /// 탭 전환으로 view가 disappear되어도 ViewModel은 `@State`로 살아있어 구독이 끊기지 않는다.
    /// `nonisolated(unsafe)`: Swift 6의 nonisolated `deinit`에서 cancel을 호출하기 위함.
    /// Task는 Sendable이고 `cancel()`은 어디서 불러도 안전하다.
    nonisolated(unsafe) private var observeTask: Task<Void, Never>?
    /// 본문에 무엇을 보여줄지 — 사용자 리스트 또는 시스템 필터. 초기 적재 직후
    /// `.list(첫 리스트.id)`로 자동 설정된다.
    var selection: ReminderSelection?
    var errorMessage: String?
    /// 옵션 메뉴 — 완료된 항목 섹션을 함께 보여줄지. 기본 OFF.
    var showsCompleted = false

    /// 섹션(오늘·개별 리스트)별 정렬 설정 캐시 — 스코프 키 → 설정. 스코프 진입 시 fetch해
    /// 채우고, 정렬 변경·드래그 직후 갱신·persist한다. 없으면 `.default`(수동·생성일 시드).
    /// 전체·예정은 이 캐시를 쓰지 않는다(고정 정렬).
    private var sortSettingsByScope: [String: ReminderSortSettings] = [:]

    /// 라이브 액티비티 활성 상태 — 동그라미 버튼의 시각 상태 + 토글 분기에 사용.
    /// 사용자가 시스템 UI에서 종료한 경우 sync는 미흡(추후 service `isActive(_:)` query
    /// 추가 시 보강). 우선은 단순 로컬 토글.
    private(set) var liveActivityActive = false

    /// 사용자 리스트가 선택돼 있을 때만 그 ID. 시스템 필터 모드면 nil.
    /// 기존 호출처(옵션 메뉴, 시트, 삭제 confirmation 등)가 이 값으로 list 컨텍스트를 본다.
    var selectedListID: String? {
        if case .list(let id) = selection { return id }
        return nil
    }

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestRemindersAccess
        self.fetchListsUseCase = dependencies.fetchReminderLists
        self.fetchRemindersUseCase = dependencies.fetchReminders
        self.toggleCompletionUseCase = dependencies.toggleReminderCompletion
        self.addReminderUseCase = dependencies.addReminder
        self.updateReminderUseCase = dependencies.updateReminder
        self.deleteReminderUseCase = dependencies.deleteReminder
        self.addReminderListUseCase = dependencies.addReminderList
        self.updateReminderListUseCase = dependencies.updateReminderList
        self.deleteReminderListUseCase = dependencies.deleteReminderList
        self.observeChangesUseCase = dependencies.observeRemindersChanges
        self.fetchSortSettingsUseCase = dependencies.fetchReminderSortSettings
        self.saveSortSettingsUseCase = dependencies.saveReminderSortSettings
        self.startLiveActivityUseCase = dependencies.startReminderLiveActivity
        self.endLiveActivityUseCase = dependencies.endReminderLiveActivity
        self.consumeLiveActivation = dependencies.consumeLiveActivation
        startObservingChanges()
    }

    /// 변경 신호 stream을 별도 Task로 구독한다 — `.task` 같은 view-bound task에 묶지 않아
    /// 탭 전환에도 살아있고, ViewModel deinit 시 자동 cleanup된다.
    /// 신호는 첫 적재(`hasLoaded`)와 권한 확인이 끝난 뒤에만 reload로 이어진다 —
    /// init 시점에 신호가 와도 무시되어 race를 만들지 않는다.
    private func startObservingChanges() {
        let stream = observeChangesUseCase()
        observeTask = Task { [weak self] in
            for await _ in stream {
                await self?.handleExternalChange()
            }
        }
    }

    /// 외부 변경 신호를 받아 reload — 권한이 있고 첫 적재가 끝났을 때만.
    private func handleExternalChange() async {
        guard access == .granted, hasLoaded else { return }
        await reload()
    }

    /// 동그라미 버튼 액션 — 라이브 액티비티 토글.
    /// 활성이면 즉시 종료. 아니면 현재 selection 제목 + visible reminders 스냅샷으로 시작.
    /// cap(6) + remaining 계산은 `StartReminderLiveActivityUseCase`에서.
    /// 무료 하루 한도를 먼저 소비 — `.denied`면 기존 LA를 건드리지 않는다(뷰가 Premium 토스트).
    @discardableResult
    func toggleLiveActivity(listTitle: String) async -> LiveActivationVerdict? {
        let verdict = await consumeLiveActivation()
        guard case .allowed = verdict else { return verdict }
        // 떠 있으면 끄고 다시 켠다(새로고침) — 더는 단순 종료하지 않는다.
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
        do {
            try await startLiveActivityUseCase(
                listTitle: listTitle,
                reminders: visibleReminders,
                listColors: listColorsByID
            )
            liveActivityActive = true
        } catch {
            errorMessage = "라이브 액티비티를 시작할 수 없습니다."
            return nil
        }
        return verdict
    }

    /// 항상 표시 자동 게시 — 권한이 있으면 데이터를 적재하고 **전체 필터 스냅샷**으로 LA 시작
    /// (사용자의 현재 선택과 무관 — 자동 게시는 항상 전체 미완료 기준, 마감 가까운 순).
    /// 사용자 탭이 아니므로 하루 쿼터를 소비하지 않는다. 이미 켜져 있으면 건너뛴다.
    func startAlwaysOnLiveActivity() async {
        guard !liveActivityActive else { return }
        await onAppear()
        guard access == .granted else { return }
        let allIncomplete = allReminders
            .filter { !$0.isCompleted }
            .sorted { compareOptionalDate($0.dueDate, $1.dueDate, ascending: true) }
        do {
            try await startLiveActivityUseCase(
                listTitle: SystemFilter.all.title,
                reminders: allIncomplete,
                listColors: listColorsByID
            )
            liveActivityActive = true
        } catch {
            // 자동 경로 — 조용히 무시.
        }
    }

    deinit {
        observeTask?.cancel()
    }

    /// 현재 선택된 리스트.
    var selectedList: ReminderList? {
        lists.first { $0.id == selectedListID }
    }

    /// 리스트 ID → 색(`"#RRGGBB"`) 매핑. 라이브 액티비티가 항목별 동그라미 색을 채울 때 쓴다.
    /// 색이 없는(`colorHex == nil`) 리스트는 매핑에서 빠져 위젯이 시스템 색으로 폴백한다.
    var listColorsByID: [String: String] {
        Dictionary(uniqueKeysWithValues: lists.compactMap { list in
            list.colorHex.map { (list.id, $0) }
        })
    }

    /// 현재 selection의 표시 제목 — LA 시작/갱신에 쓴다(View의 `currentTitle`과 동일 규칙).
    var currentSelectionTitle: String {
        switch selection {
        case .list: return selectedList?.title ?? ""
        case .systemFilter(let filter): return filter.title
        case .none: return ""
        }
    }

    /// 항목을 다시 가져오고, 활성 LA가 있으면 새 스냅샷으로 갱신한다.
    /// 완료·추가·수정·삭제 등 데이터 변경 경로의 공통 마무리.
    private func reloadReminders() async throws {
        allReminders = try await fetchRemindersUseCase()
        await refreshLiveActivityIfActive()
    }

    /// LA가 떠 있으면 현재 selection 스냅샷으로 다시 게시한다. 같은 리스트면 service가 부드럽게
    /// `update`, 리스트가 바뀌었으면 재시작한다. 갱신 실패는 조용히 무시(화면 흐름 방해 금지).
    private func refreshLiveActivityIfActive() async {
        guard liveActivityActive else { return }
        try? await startLiveActivityUseCase(
            listTitle: currentSelectionTitle,
            reminders: visibleReminders,
            listColors: listColorsByID
        )
    }

    /// 본문에 보여줄 **미완료** 항목. selection 종류에 따라 필터되고 정렬된다.
    /// - `.list(id)`: 그 리스트의 미완료. 스코프(`list:<id>`)의 정렬 설정 적용(기본 수동·생성순 시드).
    /// - `.systemFilter(.today)`: 오늘 자정 이전 마감(overdue 포함) 미완료. `today` 스코프 정렬 설정 적용.
    /// - `.systemFilter(.scheduled)`: 마감일이 있는 모든 미완료, **마감일 오름차순**(빠른 순, 고정).
    /// - `.systemFilter(.all)`: 모든 미완료, **마감일 오름차순**(가까운 순, 마감 없음 맨 뒤).
    ///   화면은 `allModeSections`로 따로 그리므로 이 목록은 LA 스냅샷 전용이다.
    var visibleReminders: [Reminder] {
        let incomplete = allReminders.filter { !$0.isCompleted }
        switch selection {
        case .list(let id):
            let items = incomplete.filter { $0.listID == id }
            return sortedBySettings(items, scope: Self.listScopeKey(id))
        case .systemFilter(.today):
            // 오늘 자정(다음날 0시) 이전 마감이면 모두 포함 — overdue + 오늘 마감.
            let tomorrowMidnight = Calendar.current.startOfDay(for: Date())
                .addingTimeInterval(24 * 60 * 60)
            let items = incomplete.filter { guard let due = $0.dueDate else { return false }
                                            return due < tomorrowMidnight }
            return sortedBySettings(items, scope: Self.todayScopeKey)
        case .systemFilter(.scheduled):
            // 마감일 오름차순 — 가장 빠른 마감이 위, 가장 먼 마감이 아래(고정).
            return incomplete
                .filter { $0.dueDate != nil }
                .sorted { compareOptionalDate($0.dueDate, $1.dueDate, ascending: true) }
        case .systemFilter(.all):
            // 화면(전체)은 `allModeSections`(리스트별·생성순)로 그리므로, 이 평탄 목록은 사실상
            // **라이브 액티비티 스냅샷 전용**이다. LA는 마감일 오름차순(가까운 순)으로,
            // 마감 없음은 맨 뒤로 보여준다.
            return incomplete.sorted { compareOptionalDate($0.dueDate, $1.dueDate, ascending: true) }
        case .none:
            return []
        }
    }

    // MARK: - 섹션별 정렬 설정 (오늘·개별 리스트)

    /// 오늘 섹션의 정렬 스코프 키.
    static let todayScopeKey = "today"
    /// 개별 리스트 섹션의 정렬 스코프 키.
    static func listScopeKey(_ listID: String) -> String { "list:\(listID)" }

    /// 현재 selection의 정렬 스코프 키 — 오늘·개별 리스트에서만 존재.
    /// 전체·예정·미선택은 nil(정렬 메뉴·드래그 비활성).
    var currentSortScopeKey: String? {
        switch selection {
        case .systemFilter(.today): return Self.todayScopeKey
        case .list(let id): return Self.listScopeKey(id)
        default: return nil
        }
    }

    /// 정렬 메뉴를 노출할지 — 오늘·개별 리스트에서만.
    var canSort: Bool { currentSortScopeKey != nil }

    /// 현재 스코프의 정렬 기준+방향. 스코프가 없거나 미적재면 `.default`.
    var currentSortPreference: ReminderSortPreference {
        guard let key = currentSortScopeKey else { return .default }
        return (sortSettingsByScope[key] ?? .default).preference
    }

    /// 정렬 기준을 바꾼다(방향은 유지). 전체·예정에선 무시.
    func selectSortField(_ field: ReminderSortField) async {
        await updateCurrentSortPreference { $0.field = field }
    }

    /// 정렬 방향을 바꾼다. 전체·예정에선 무시.
    func selectSortDirection(_ direction: ReminderSortDirection) async {
        await updateCurrentSortPreference { $0.direction = direction }
    }

    /// 드래그 재배열 — 현재 보이는 순서를 기준으로 이동을 적용한 뒤, 정렬 기준을 '수동'으로
    /// 전환하고 그 순서를 저장한다. 어떤 정렬 상태에서 끌어도 드롭하는 순간 수동이 된다.
    /// 전체·예정(스코프 없음)에선 무시.
    func moveReminders(fromOffsets source: IndexSet, toOffset destination: Int) async {
        guard let key = currentSortScopeKey else { return }
        let ids = Self.movingElements(visibleReminders.map(\.id), fromOffsets: source, toOffset: destination)
        var settings = sortSettingsByScope[key] ?? .default
        settings.preference.field = .manual
        settings.manualOrder = ids
        sortSettingsByScope[key] = settings
        await saveSortSettingsUseCase(settings, scope: key)
    }

    /// SwiftUI `RangeReplaceableCollection.move(fromOffsets:toOffset:)`와 같은 의미를
    /// Foundation만으로 구현한다(ViewModel은 SwiftUI를 import하지 않으므로).
    /// `destination`은 원본 기준 삽입 위치 — 제거된 앞쪽 항목 수만큼 보정한다.
    static func movingElements<T>(_ array: [T], fromOffsets source: IndexSet, toOffset destination: Int) -> [T] {
        let moving = source.map { array[$0] }
        var result = array
        for index in source.sorted(by: >) { result.remove(at: index) }
        let removedBefore = source.filter { $0 < destination }.count
        result.insert(contentsOf: moving, at: destination - removedBefore)
        return result
    }

    /// 현재 스코프 설정의 preference를 변형해 캐시 갱신 + 영속 저장.
    private func updateCurrentSortPreference(
        _ mutate: (inout ReminderSortPreference) -> Void
    ) async {
        guard let key = currentSortScopeKey else { return }
        var settings = sortSettingsByScope[key] ?? .default
        mutate(&settings.preference)
        sortSettingsByScope[key] = settings
        await saveSortSettingsUseCase(settings, scope: key)
    }

    /// 현재 스코프의 정렬 설정을 fetch해 캐시에 채운다(이미 있으면 건너뜀).
    private func loadSortSettingsForCurrentScope() async {
        guard let key = currentSortScopeKey, sortSettingsByScope[key] == nil else { return }
        sortSettingsByScope[key] = await fetchSortSettingsUseCase(scope: key)
    }

    /// 선택 변경 직후 백그라운드로 그 스코프 설정을 적재한다 — 동기 select/selectFilter용.
    private func loadSortSettingsInBackground() {
        guard let key = currentSortScopeKey, sortSettingsByScope[key] == nil else { return }
        Task { await loadSortSettingsForCurrentScope() }
    }

    /// 스코프 설정에 따라 정렬한다.
    private func sortedBySettings(_ reminders: [Reminder], scope key: String) -> [Reminder] {
        let settings = sortSettingsByScope[key] ?? .default
        return applySort(reminders, preference: settings.preference, manualOrder: settings.manualOrder)
    }

    /// 정렬 기준·방향·수동순서를 적용한다.
    private func applySort(
        _ reminders: [Reminder],
        preference: ReminderSortPreference,
        manualOrder: [String]
    ) -> [Reminder] {
        switch preference.field {
        case .manual:
            return manualSorted(reminders, order: manualOrder)
        case .dueDate:
            let asc = preference.direction == .ascending
            return reminders.sorted { compareOptionalDate($0.dueDate, $1.dueDate, ascending: asc) }
        case .creationDate:
            let asc = preference.direction == .ascending
            return reminders.sorted { compareOptionalDate($0.creationDate, $1.creationDate, ascending: asc) }
        case .title:
            return reminders.sorted { lhs, rhs in
                let order = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                return preference.direction == .ascending
                    ? order == .orderedAscending
                    : order == .orderedDescending
            }
        }
    }

    /// 수동 순서 정렬 — `order`에 있는 ID 순으로. 목록에 없는(새) 항목은 맨 뒤,
    /// 그들끼리는 생성일 오래된 순(시드). `order`가 비면 전체가 생성일 시드 순.
    private func manualSorted(_ reminders: [Reminder], order: [String]) -> [Reminder] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return reminders.sorted { lhs, rhs in
            switch (rank[lhs.id], rank[rhs.id]) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return compareOptionalDate(lhs.creationDate, rhs.creationDate, ascending: true)
            }
        }
    }

    /// 옵셔널 날짜 비교 — nil은 방향과 무관하게 항상 맨 뒤로.
    private func compareOptionalDate(_ a: Date?, _ b: Date?, ascending: Bool) -> Bool {
        switch (a, b) {
        case let (x?, y?): return ascending ? x < y : x > y
        case (_?, nil): return true   // 값 있는 쪽이 앞
        case (nil, _?): return false
        case (nil, nil): return false
        }
    }

    /// 생성순(추가한 순서) 오름차순 — 먼저 추가한 항목이 위, 나중에 추가한 항목이 아래.
    /// 미리 알림 앱의 전체·예정 기본 정렬과 동일. nil은 `distantFuture`로 취급해 맨 뒤로
    /// (생성일 미상은 가장 나중에 추가된 것으로 본다).
    private func creationDateAscendingNilLast(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        (lhs.creationDate ?? .distantFuture) < (rhs.creationDate ?? .distantFuture)
    }

    /// `.all` 모드에서 본문에 그릴 (리스트, 미완료, 완료) 묶음.
    /// 리스트 표시 순서는 `lists`와 동일하고, 미완료는 **생성순**(추가한 순서) — 미리 알림
    /// 앱 "전체"와 동일. 완료 항목은 EventKit 원본 순서(다른 모드의 `completedReminders`와
    /// 동일 처리) — `showsCompleted` OFF면 빈 배열.
    /// 빈 리스트도 포함한다(섹션 헤더는 보여야 하므로).
    var allModeSections: [(list: ReminderList, active: [Reminder], completed: [Reminder])] {
        lists.map { list in
            let active = allReminders
                .filter { $0.listID == list.id && !$0.isCompleted }
                .sorted(by: creationDateAscendingNilLast)
            let completed = showsCompleted
                ? allReminders.filter { $0.listID == list.id && $0.isCompleted }
                : []
            return (list, active, completed)
        }
    }

    /// 리스트별 미완료 항목 수 — 리스트 선택 메뉴 옆 카운트 표기용.
    func incompleteCount(for list: ReminderList) -> Int {
        allReminders.reduce(into: 0) { count, reminder in
            if reminder.listID == list.id && !reminder.isCompleted { count += 1 }
        }
    }

    /// 선택된 리스트의 **완료** 항목 — "완료된 항목 보기" 토글이 켜졌을 때만 화면에 추가된다.
    var completedReminders: [Reminder] {
        guard let selectedListID else { return [] }
        return allReminders.filter { $0.listID == selectedListID && $0.isCompleted }
    }

    /// 화면 진입 시 — 권한 확인 + 첫 진입에만 적재. 변경 구독은 `init`이 시작한 별도 Task가
    /// 백그라운드로 담당하므로 여기서는 따로 await하지 않는다 — 탭 전환 깜박임 없음.
    func onAppear() async {
        access = await requestAccessUseCase()
        guard access == .granted else { return }
        if !hasLoaded {
            await reload()
            hasLoaded = true
        }
    }

    /// 리스트·항목을 다시 가져온다. selection이 비어 있거나 그 리스트가 사라졌으면
    /// 첫 리스트로 자동 전환한다 (시스템 필터 selection은 그대로 둔다).
    func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            if needsResetToFirstList, let first = lists.first {
                selection = .list(first.id)
            }
            // 현재 스코프(오늘·개별 리스트)의 정렬 설정을 적재 — 진입 시 저장된 정렬 복원.
            await loadSortSettingsForCurrentScope()
            // 외부(미리 알림 앱) 변경 등으로 데이터가 바뀌면 떠 있는 LA도 따라 갱신.
            await refreshLiveActivityIfActive()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// reload 후 selection을 첫 리스트로 떨어뜨려야 하는 상황 — 초기 진입이거나
    /// 가리키던 리스트가 사라진 경우. 시스템 필터 selection은 영향 없음.
    private var needsResetToFirstList: Bool {
        switch selection {
        case .none: return true
        case .list(let id): return !lists.contains(where: { $0.id == id })
        case .systemFilter: return false
        }
    }

    func select(_ list: ReminderList) {
        selection = .list(list.id)
        loadSortSettingsInBackground()
    }

    /// 시스템 필터(오늘/예정/전체)로 전환한다. 사용자 리스트 selection은 해제된다.
    func selectFilter(_ filter: SystemFilter) {
        selection = .systemFilter(filter)
        loadSortSettingsInBackground()
    }

    func toggle(_ reminder: Reminder) async {
        do {
            try await toggleCompletionUseCase(reminder)
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        includesTime: Bool = false,
        toListID: String? = nil
    ) async {
        guard let listID = toListID ?? resolveTargetListID() else {
            errorMessage = "먼저 리스트를 선택해 주세요."
            return
        }
        do {
            try await addReminderUseCase(
                title: title,
                notes: notes,
                dueDate: dueDate,
                includesTime: includesTime,
                listID: listID
            )
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 새 미리알림이 어느 리스트로 저장될지 결정한다.
    /// - 사용자 리스트가 selection이면 그 리스트로.
    /// - 시스템 필터 selection(오늘/예정/전체)이면 이름이 "미리 알림"인 리스트 우선,
    ///   없으면 `lists.first`로 fallback.
    private func resolveTargetListID() -> String? {
        if let selectedListID { return selectedListID }
        if let named = lists.first(where: { $0.title == "미리 알림" }) { return named.id }
        return lists.first?.id
    }

    /// 기존 항목의 제목·메모·마감일을 수정한다.
    func update(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date? = nil,
        includesTime: Bool = false
    ) async {
        do {
            try await updateReminderUseCase(
                reminderID: reminderID,
                title: title,
                notes: notes,
                dueDate: dueDate,
                includesTime: includesTime
            )
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 항목을 삭제한다.
    func delete(_ reminder: Reminder) async {
        do {
            try await deleteReminderUseCase(reminderID: reminder.id)
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 새 리스트 생성 — 만들고 나서 그 리스트로 자동 전환한다.
    func addList(title: String, colorHex: String?) async {
        do {
            let newID = try await addReminderListUseCase(title: title, colorHex: colorHex)
            lists = try await fetchListsUseCase()
            selection = .list(newID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 기존 리스트의 이름·색을 수정.
    func updateList(listID: String, title: String, colorHex: String?) async {
        do {
            try await updateReminderListUseCase(listID: listID, title: title, colorHex: colorHex)
            lists = try await fetchListsUseCase()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 리스트 삭제 — 안에 있는 모든 항목도 함께 사라진다.
    /// 삭제된 리스트를 보고 있었다면 남은 첫 리스트로(없으면 nil) selection을 옮긴다.
    func deleteList(listID: String) async {
        do {
            try await deleteReminderListUseCase(listID: listID)
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            if selectedListID == listID {
                selection = lists.first.map { .list($0.id) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
