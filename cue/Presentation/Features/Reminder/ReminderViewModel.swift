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
    private let currentAccessUseCase: CurrentRemindersAccessUseCase
    private let loadSnapshotUseCase: LoadRemindersSnapshotUseCase
    private let saveSnapshotUseCase: SaveRemindersSnapshotUseCase
    private let fetchListsUseCase: FetchReminderListsUseCase
    private let fetchRemindersUseCase: FetchRemindersUseCase
    private let toggleCompletionUseCase: ToggleReminderCompletionUseCase
    private let addReminderUseCase: AddReminderUseCase
    private let updateReminderUseCase: UpdateReminderUseCase
    private let deleteReminderUseCase: DeleteReminderUseCase
    private let moveReminderUseCase: MoveReminderUseCase
    private let addReminderListUseCase: AddReminderListUseCase
    private let updateReminderListUseCase: UpdateReminderListUseCase
    private let deleteReminderListUseCase: DeleteReminderListUseCase
    private let observeChangesUseCase: ObserveRemindersChangesUseCase
    private let fetchSortSettingsUseCase: FetchReminderSortSettingsUseCase
    private let saveSortSettingsUseCase: SaveReminderSortSettingsUseCase
    private let startLiveActivityUseCase: StartReminderLiveActivityUseCase
    private let endLiveActivityUseCase: EndReminderLiveActivityUseCase
    private let consumeLiveActivation: ConsumeLiveActivationUseCase
    private let fetchAppSettings: FetchAppSettingsUseCase
    private let analytics: any AnalyticsService
    /// 프리미엄 여부의 반응형 소스 — 라이브 한도 소비 시 호출 시점에 읽는다(구매 즉시 반영).
    private let premiumStore: PremiumStore
    /// 이번 주 캘린더 이벤트 조회 — 할일 LA도 일정 LA와 같은 주간 스트립(날짜별 일정 점)을
    /// 그리므로 발행 시 캘린더 이벤트를 함께 싣는다. 캘린더 권한 없으면 조용히 빈 배열.
    private let fetchEventsUseCase: FetchEventsUseCase

    private(set) var access: RemindersAccess = .notDetermined
    private(set) var lists: [ReminderList] = []
    /// 설정에서 숨긴 리스트 id — 숨긴 리스트의 할일은 오늘·예정·전체 어디서도 안 보이고 칩에서도 빠진다.
    private(set) var hiddenReminderListIDs: Set<String> = []
    private(set) var allReminders: [Reminder] = []
    private(set) var isLoading = false
    /// 현재 시각 공급자 — 자기 쓰기 에코 억제 창 판정에 쓴다(테스트에서 주입).
    private let now: () -> Date
    /// 이 시각 전까지 온 외부 변경 신호는 무시한다 — 앱 자신의 EventKit 쓰기가 되쏘는 알림이
    /// 인라인 편집→새 행 포커스 이동 중 리스트를 remount해 커서를 끊는 걸 막는다.
    private var suppressObserveUntil: Date = .distantPast
    /// 첫 데이터 적재가 끝났는지. `onAppear`가 탭 전환마다 재호출되더라도 두 번째
    /// 이상은 fetch를 건너뛴다 — 외부(미리 알림 앱)에서 실제 변경이 발생하면 그때만
    /// `observeTask`의 stream이 신호를 보내 reload가 호출되어 인디케이터 깜박임이 사라진다.
    private var hasLoaded = false
    /// 진행 중인 첫 적재 — 앱 시작 프리페치와 탭 진입 `onAppear`가 동시에 도착해도
    /// 첫 적재는 정확히 한 번만 돌도록 single-flight로 공유한다.
    private var firstLoadTask: Task<Void, Never>?
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

    init(
        dependencies: Dependencies,
        premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService()),
        now: @escaping () -> Date = { Date() }
    ) {
        self.now = now
        self.premiumStore = premiumStore
        self.requestAccessUseCase = dependencies.requestRemindersAccess
        self.currentAccessUseCase = dependencies.currentRemindersAccess
        self.loadSnapshotUseCase = dependencies.loadRemindersSnapshot
        self.saveSnapshotUseCase = dependencies.saveRemindersSnapshot
        self.fetchListsUseCase = dependencies.fetchReminderLists
        self.fetchRemindersUseCase = dependencies.fetchReminders
        self.toggleCompletionUseCase = dependencies.toggleReminderCompletion
        self.addReminderUseCase = dependencies.addReminder
        self.updateReminderUseCase = dependencies.updateReminder
        self.deleteReminderUseCase = dependencies.deleteReminder
        self.moveReminderUseCase = dependencies.moveReminder
        self.addReminderListUseCase = dependencies.addReminderList
        self.updateReminderListUseCase = dependencies.updateReminderList
        self.deleteReminderListUseCase = dependencies.deleteReminderList
        self.observeChangesUseCase = dependencies.observeRemindersChanges
        self.fetchSortSettingsUseCase = dependencies.fetchReminderSortSettings
        self.saveSortSettingsUseCase = dependencies.saveReminderSortSettings
        self.startLiveActivityUseCase = dependencies.startReminderLiveActivity
        self.endLiveActivityUseCase = dependencies.endReminderLiveActivity
        self.consumeLiveActivation = dependencies.consumeLiveActivation
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.fetchEventsUseCase = dependencies.fetchEvents
        self.analytics = dependencies.analytics
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
    /// **인디케이터 없이** 조용히 갱신한다: 이 신호는 앱 자신의 쓰기(EventKit이 되쏘는 알림)로도
    /// 오므로, 스피너를 띄우면 엔터마다 화면이 깜빡인다. Apple 미리알림처럼 무침습으로 반영한다.
    private func handleExternalChange() async {
        guard access == .granted, hasLoaded else { return }
        // 자기 쓰기 직후(억제 창 이내)의 에코 신호는 무시 — 자기 쓰기는 이미 reloadReminders로
        // 반영했고, 여기서 또 reload하면 포커스 이동 중 remount로 커서가 끊긴다.
        guard now() >= suppressObserveUntil else { return }
        await reload(showsIndicator: false)
    }

    /// 자기 쓰기 에코 억제 창을 연다 — 이후 짧은 시간 동안 외부 변경 신호를 무시한다.
    /// EventKit이 쓰기 알림을 (동기 완료 뒤) 살짝 늦게 쏘므로 넉넉히 둔다.
    private static let selfWriteSuppressWindow: TimeInterval = 2

    /// 동그라미 버튼 액션 — 라이브 액티비티 토글.
    /// 활성이면 즉시 종료. 아니면 현재 selection 제목 + visible reminders 스냅샷으로 시작.
    /// cap(6) + remaining 계산은 `StartReminderLiveActivityUseCase`에서.
    /// 무료 하루 한도를 먼저 소비 — `.denied`면 기존 LA를 건드리지 않는다(뷰가 Premium 토스트).
    @discardableResult
    func toggleLiveActivity(listTitle: String) async -> LiveActivationVerdict? {
        let verdict = await consumeLiveActivation(isPremium: premiumStore.isPremium)
        // .allowed(무료 한도 내)·.unlimited(Premium) 모두 켠다 — .denied(한도 초과)만 막는다.
        if case .denied = verdict {
            analytics.log(.liveDenied(kind: "tasks"))
            return verdict
        }
        // 떠 있으면 끄고 다시 켠다(새로고침) — 더는 단순 종료하지 않는다.
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
        do {
            try await startLiveActivityUseCase(
                listTitle: listTitle,
                reminders: visibleReminders,
                listColors: listColorsByID,
                weekEvents: await fetchWeekEvents()
            )
            liveActivityActive = true
            analytics.log(.liveToggled(kind: "tasks", on: true))
        } catch {
            errorMessage = String(localized: "Couldn't start Live Activity.")
            return nil
        }
        return verdict
    }

    /// 항상 표시 자동 게시 — 권한이 있으면 데이터를 적재하고 **설정의 할일 범위**
    /// (오늘/예정/전체/사용자 리스트) 스냅샷으로 LA 시작. 사용자의 현재 선택과는 무관하다.
    /// 사용자 탭이 아니므로 하루 쿼터를 소비하지 않는다. 이미 켜져 있으면 건너뛴다.
    /// `force`면 이미 활성이어도 다시 게시한다 — 설정에서 범위를 바꾼 직후 반영용.
    func startAlwaysOnLiveActivity(force: Bool = false) async {
        // 항상 표시는 Premium 전용 — 게시 시점에 재확인(구독 만료·과거 저장값 잔존 방어).
        guard premiumStore.isPremium else { return }
        guard force || !liveActivityActive else { return }
        await onAppear()
        guard access == .granted else { return }

        let scopeID = await fetchAppSettings().liveAlwaysOnReminderScopeID
        // 사용자 리스트 id가 삭제됐으면 전체로 폴백.
        let scope = ReminderSelection.resolve(
            scopeID: scopeID, lists: lists, fallback: .systemFilter(.all)
        )
        let title: String
        switch scope {
        case .list(let id): title = lists.first(where: { $0.id == id })?.title ?? SystemFilter.all.title
        case .systemFilter(let filter): title = filter.title
        }

        do {
            try await startLiveActivityUseCase(
                listTitle: title,
                reminders: snapshot(for: scope),
                listColors: listColorsByID,
                weekEvents: await fetchWeekEvents()
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

    /// 이번 주(로케일 주 시작 요일 기준 7일) 캘린더 이벤트 — Dynamic Island 주간 스트립의
    /// 날짜별 일정 점 계산용. 캘린더 권한이 없거나 조회 실패면 빈 배열(점 없음).
    private func fetchWeekEvents() async -> [CalendarEvent] {
        guard let week = WeekEventDotsBuilder.weekRange(for: Date()) else { return [] }
        return (try? await fetchEventsUseCase(from: week.start, to: week.end)) ?? []
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
        // 자기 쓰기 완료 — 잠깐 동안 EventKit이 되쏘는 외부 변경 에코를 무시한다.
        suppressObserveUntil = now().addingTimeInterval(Self.selfWriteSuppressWindow)
        await refreshLiveActivityIfActive()
        // 자기 쓰기 결과도 스냅샷에 반영 — 껐다 켜도 방금 추가·수정한 항목이 즉시 보인다.
        await saveSnapshotUseCase(RemindersSnapshot(lists: lists, reminders: allReminders))
    }

    /// LA가 떠 있으면 현재 selection 스냅샷으로 다시 게시한다. 같은 리스트면 service가 부드럽게
    /// `update`, 리스트가 바뀌었으면 재시작한다. 갱신 실패는 조용히 무시(화면 흐름 방해 금지).
    private func refreshLiveActivityIfActive() async {
        guard liveActivityActive else { return }
        try? await startLiveActivityUseCase(
            listTitle: currentSelectionTitle,
            reminders: visibleReminders,
            listColors: listColorsByID,
            weekEvents: await fetchWeekEvents()
        )
    }

    /// 본문에 보여줄 **미완료** 항목. selection 종류에 따라 필터되고 정렬된다.
    /// - `.list(id)`: 그 리스트의 미완료. 스코프(`list:<id>`)의 정렬 설정 적용(기본 수동·생성순 시드).
    /// - `.systemFilter(.today)`: 오늘 자정 이전 마감(overdue 포함) 미완료. `today` 스코프 정렬 설정 적용.
    /// - `.systemFilter(.scheduled)`: 마감일이 있는 모든 미완료, **마감일 오름차순**(빠른 순, 고정).
    /// - `.systemFilter(.all)`: 모든 미완료, **마감일 오름차순**(가까운 순, 마감 없음 맨 뒤).
    ///   화면은 `allModeSections`로 따로 그리므로 이 목록은 LA 스냅샷 전용이다.
    var visibleReminders: [Reminder] {
        snapshot(for: selection)
    }

    /// 주어진 선택 기준의 LA 스냅샷 — 화면(visibleReminders)과 항상 표시 자동 게시가 공유한다.
    /// 숨긴 리스트를 제외한 표시용 리스트 — 목록 칩·전체 모드 섹션이 사용한다.
    var visibleLists: [ReminderList] {
        lists.filter { !hiddenReminderListIDs.contains($0.id) }
    }

    /// 설정에서 숨김 목록이 바뀌면 즉시 반영한다(설정 탭에서 토글 → 할일 화면 즉시 갱신).
    /// 현재 보고 있던 리스트가 숨겨졌으면 '전체' 필터로 떨어뜨린다.
    func applyHiddenReminderLists(_ ids: Set<String>) {
        hiddenReminderListIDs = ids
        if case .list(let id) = selection, ids.contains(id) {
            selection = .systemFilter(.all)
        }
    }

    private func snapshot(for selection: ReminderSelection?) -> [Reminder] {
        // 숨긴 리스트의 할일은 어떤 필터에서도 제외 — 캘린더 숨김과 동일.
        let incomplete = allReminders.filter { !$0.isCompleted && !hiddenReminderListIDs.contains($0.listID) }
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
        analytics.log(.reminderReordered)
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
        // 정렬 메뉴 선택만 이 경로를 탄다 — 드래그의 수동 전환은 `.reminderReordered`로 따로 센다.
        analytics.log(.reminderSortChanged(
            key: settings.preference.field.rawValue,
            order: settings.preference.direction.rawValue
        ))
    }

    /// 현재 스코프의 정렬 설정을 fetch해 캐시에 채운다(이미 있으면 건너뜀).
    private func loadSortSettingsForCurrentScope() async {
        guard let key = currentSortScopeKey, sortSettingsByScope[key] == nil else { return }
        sortSettingsByScope[key] = await fetchSortSettingsUseCase(scope: key)
    }

    /// 모든 리스트 스코프의 정렬 설정을 채운다 — `.all` 모드 섹션들이 리스트별 저장 정렬을
    /// 쓰므로 어떤 리스트가 화면에 나와도 순서가 복원되게 reload 시 함께 적재한다.
    private func loadSortSettingsForAllLists() async {
        for list in lists {
            let key = Self.listScopeKey(list.id)
            if sortSettingsByScope[key] == nil {
                sortSettingsByScope[key] = await fetchSortSettingsUseCase(scope: key)
            }
        }
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


    /// `.all` 모드에서 본문에 그릴 (리스트, 미완료, 완료) 묶음.
    /// 리스트 표시 순서는 `lists`와 동일하고, 미완료는 **생성순**(추가한 순서) — 미리 알림
    /// 앱 "전체"와 동일. 완료 항목은 EventKit 원본 순서(다른 모드의 `completedReminders`와
    /// 동일 처리) — `showsCompleted` OFF면 빈 배열.
    /// 빈 리스트도 포함한다(섹션 헤더는 보여야 하므로).
    var allModeSections: [(list: ReminderList, active: [Reminder], completed: [Reminder])] {
        visibleLists.map { list in
            let completed = showsCompleted
                ? allReminders.filter { $0.listID == list.id && $0.isCompleted }
                : []
            return (list, sectionActiveReminders(listID: list.id), completed)
        }
    }

    /// `.all` 모드의 평탄화된 행 — 리스트마다 헤더 → 미완료 항목 → (완료) → 입력 슬롯 → 디바이더.
    /// List의 Section 조합은 .onMove가 섹션을 넘지 못하고 .onInsert/.onDrop은 List 안에서
    /// 불리지 않으므로, 단일 ForEach + .onMove가 섹션 간 드래그의 유일한 네이티브 경로다.
    enum AllModeRow: Identifiable, Equatable {
        case header(ReminderList)
        case reminder(Reminder)
        case completed(Reminder)
        /// 새 입력 행 자리 — 활성/placeholder 분기는 View가 한다.
        case inputSlot(listID: String)
        case divider(listID: String)

        var id: String {
            switch self {
            case .header(let list): return "header:\(list.id)"
            case .reminder(let reminder): return "reminder:\(reminder.id)"
            case .completed(let reminder): return "completed:\(reminder.id)"
            case .inputSlot(let listID): return "input:\(listID)"
            case .divider(let listID): return "divider:\(listID)"
            }
        }
    }

    /// `.all` 모드 화면이 그리는 평탄 행 목록 — `allModeSections`를 행 단위로 편 것.
    var allModeRows: [AllModeRow] {
        allModeSections.flatMap { section -> [AllModeRow] in
            [.header(section.list)]
                + section.active.map(AllModeRow.reminder)
                + section.completed.map(AllModeRow.completed)
                + [.inputSlot(listID: section.list.id), .divider(listID: section.list.id)]
        }
    }

    /// `.all` 모드 onMove — 평탄 인덱스를 (대상 리스트, 섹션 내 위치)로 해석해
    /// 같은 리스트면 수동 재배열, 다른 리스트면 리스트 이동으로 위임한다.
    func moveAllModeRow(fromOffsets source: IndexSet, toOffset destination: Int) async {
        let rows = allModeRows
        guard let sourceIndex = source.first,
              rows.indices.contains(sourceIndex),
              case .reminder(let moving) = rows[sourceIndex] else { return }
        guard let target = Self.allModeDropTarget(rows: rows, destination: destination) else { return }
        if target.listID == moving.listID {
            await reorderAfterDrop(reminderID: moving.id, inListID: target.listID, toOffset: target.offset)
        } else {
            await moveReminder(reminderID: moving.id, toListID: target.listID, toOffset: target.offset)
        }
    }

    /// 평탄 삽입 인덱스 → (리스트, 섹션 내 삽입 위치). destination 위쪽에서 가장 가까운 헤더가
    /// 대상 리스트, 그 헤더 이후의 미완료 행 수가 섹션 내 위치다. 완료·입력 영역에 떨어지면
    /// 그 수가 곧 active 개수라 자연히 맨 뒤. 첫 헤더보다 위면 첫 리스트 맨 앞.
    static func allModeDropTarget(rows: [AllModeRow], destination: Int) -> (listID: String, offset: Int)? {
        var currentListID: String?
        var offsetInSection = 0
        for (index, row) in rows.enumerated() {
            if index == destination { break }
            switch row {
            case .header(let list):
                currentListID = list.id
                offsetInSection = 0
            case .reminder:
                offsetInSection += 1
            case .completed, .inputSlot, .divider:
                break
            }
        }
        if let currentListID { return (currentListID, offsetInSection) }
        for row in rows {
            if case .header(let list) = row { return (list.id, 0) }
        }
        return nil
    }

    /// `.all` 모드 한 섹션의 미완료 항목 — 그 리스트의 저장된 정렬 설정을 따른다(단일 리스트
    /// 모드와 동일). 설정이 없으면 `.default`(수동 + 빈 순서 = 생성순 시드)라 기존 생성순과 같다.
    private func sectionActiveReminders(listID: String) -> [Reminder] {
        sortedBySettings(
            allReminders.filter { $0.listID == listID && !$0.isCompleted },
            scope: Self.listScopeKey(listID)
        )
    }

    /// `.all` 모드 섹션 간 드래그 — 항목을 다른 리스트로 실제 이동(EventKit calendar 교체)하고,
    /// 드랍 위치를 대상 리스트의 수동 순서에 반영한다. 원본 리스트 수동 순서에선 제거.
    func moveReminder(reminderID: String, toListID listID: String, toOffset destination: Int) async {
        guard let moving = allReminders.first(where: { $0.id == reminderID }) else { return }
        // 같은 섹션 안에 드랍 — 리스트 이동 없이 수동 재배열. `.onInsert` 드랍 경로가
        // 섹션 내 재배열까지 담당한다(.onMove는 드래그 세션을 가로채 섹션 간 이동을 막아 미사용).
        if moving.listID == listID {
            await reorderAfterDrop(reminderID: reminderID, inListID: listID, toOffset: destination)
            return
        }
        do {
            try await moveReminderUseCase(reminderID: reminderID, toListID: listID)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        analytics.log(.reminderMovedToList)

        // 대상 리스트 수동 순서 — 이동 전 대상 섹션 순서에 드랍 위치로 삽입.
        let targetKey = Self.listScopeKey(listID)
        var targetIDs = sectionActiveReminders(listID: listID).map(\.id)
        targetIDs.insert(reminderID, at: min(max(destination, 0), targetIDs.count))
        var target = sortSettingsByScope[targetKey] ?? .default
        target.preference.field = .manual
        target.manualOrder = targetIDs
        sortSettingsByScope[targetKey] = target
        await saveSortSettingsUseCase(target, scope: targetKey)

        // 원본 리스트 수동 순서에서 제거 — 낡은 ID가 남아 순위를 차지하지 않게.
        let sourceKey = Self.listScopeKey(moving.listID)
        if var source = sortSettingsByScope[sourceKey], source.manualOrder.contains(reminderID) {
            source.manualOrder.removeAll { $0 == reminderID }
            sortSettingsByScope[sourceKey] = source
            await saveSortSettingsUseCase(source, scope: sourceKey)
        }

        do {
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 같은 리스트 안 드랍 재배열 — `offset`은 원본 행이 아직 제거되지 않은 상태의 삽입
    /// 위치이므로, 원래 위치가 삽입 위치보다 앞이면 1을 보정한다. 정렬은 '수동'으로 전환·저장.
    private func reorderAfterDrop(reminderID: String, inListID listID: String, toOffset destination: Int) async {
        let key = Self.listScopeKey(listID)
        var ids = sectionActiveReminders(listID: listID).map(\.id)
        guard let oldIndex = ids.firstIndex(of: reminderID) else { return }
        ids.remove(at: oldIndex)
        let adjusted = oldIndex < destination ? destination - 1 : destination
        ids.insert(reminderID, at: min(max(adjusted, 0), ids.count))
        var settings = sortSettingsByScope[key] ?? .default
        settings.preference.field = .manual
        settings.manualOrder = ids
        sortSettingsByScope[key] = settings
        await saveSortSettingsUseCase(settings, scope: key)
        analytics.log(.reminderReordered)
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
        await ensureFirstLoad()
    }

    /// 앱 시작 프리페치 — 탭 진입을 기다리지 않고 첫 적재를 미리 끝내 스피너를 없앤다.
    /// 권한 프롬프트를 절대 유발하지 않는다: 이미 허용된 경우에만 진행하고,
    /// 미결정이면 아무것도 하지 않아 첫 탭 진입 시 기존 프롬프트 흐름이 그대로 남는다.
    func prefetch() async {
        guard !hasLoaded else { return }
        guard await currentAccessUseCase() == .granted else { return }
        access = .granted
        await ensureFirstLoad()
    }

    /// 첫 적재 single-flight — 프리페치와 onAppear가 겹쳐도 fetch는 정확히 한 번.
    private func ensureFirstLoad() async {
        if hasLoaded { return }
        if let task = firstLoadTask {
            await task.value
            return
        }
        let task = Task { await performFirstLoad() }
        firstLoadTask = task
        await task.value
        firstLoadTask = nil
    }

    /// 첫 적재 — 캐시가 있으면 스피너 없이 즉시 페인트한 뒤 조용히 최신화하고,
    /// 없으면 기존 스피너 경로. 어느 쪽이든 끝나면 `hasLoaded`.
    private func performFirstLoad() async {
        if let snapshot = await loadSnapshotUseCase() {
            lists = snapshot.lists
            allReminders = snapshot.reminders
            hiddenReminderListIDs = await fetchAppSettings().hiddenReminderListIDs
            await resolveInitialSelectionIfNeeded()
            await loadSortSettingsForCurrentScope()
            await loadSortSettingsForAllLists()
            hasLoaded = true
            await reload(showsIndicator: false)
        } else {
            await reload()
            hasLoaded = true
        }
    }

    /// 리스트·항목을 다시 가져온다. selection이 비어 있거나 그 리스트가 사라졌으면
    /// 첫 리스트로 자동 전환한다 (시스템 필터 selection은 그대로 둔다).
    /// `showsIndicator`가 false면 로딩 스피너 없이 조용히 갱신한다 — 외부 변경 신호처럼
    /// 자기 쓰기로도 오는 경로에서 화면 깜빡임을 없애기 위해. 최초 적재만 스피너를 쓴다.
    func reload(showsIndicator: Bool = true) async {
        if showsIndicator { isLoading = true }
        defer { if showsIndicator { isLoading = false } }
        do {
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            hiddenReminderListIDs = await fetchAppSettings().hiddenReminderListIDs
            await resolveInitialSelectionIfNeeded()
            // 현재 스코프(오늘·개별 리스트)의 정렬 설정을 적재 — 진입 시 저장된 정렬 복원.
            await loadSortSettingsForCurrentScope()
            // 전체 모드 섹션이 리스트별 저장 정렬을 쓰므로 모든 리스트 스코프도 채운다.
            await loadSortSettingsForAllLists()
            // 외부(미리 알림 앱) 변경 등으로 데이터가 바뀌면 떠 있는 LA도 따라 갱신.
            await refreshLiveActivityIfActive()
            // fetch 성공 결과를 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
            await saveSnapshotUseCase(RemindersSnapshot(lists: lists, reminders: allReminders))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// reload 후 selection을 보정한다.
    /// - 초기 진입(`.none`): 설정의 할일 기본 화면(`tasksDefaultScopeID`)으로 해석한다.
    ///   지정된 리스트가 없으면 첫 리스트로 폴백. 리스트가 하나도 없으면 그대로 nil.
    /// - 가리키던 리스트가 사라진 경우(`.list` & 없음): 첫 리스트로 폴백.
    /// - 시스템 필터 selection은 건드리지 않는다.
    private func resolveInitialSelectionIfNeeded() async {
        guard let first = lists.first else { return }
        switch selection {
        case .none:
            let scopeID = await fetchAppSettings().tasksDefaultScopeID
            selection = ReminderSelection.resolve(
                scopeID: scopeID, lists: lists, fallback: .list(first.id)
            )
        case .list(let id) where !lists.contains(where: { $0.id == id }):
            selection = .list(first.id)
        default:
            break
        }
    }

    func select(_ list: ReminderList) {
        selection = .list(list.id)
        loadSortSettingsInBackground()
        // 사용자 선택 경로에서만 기록 — 초기 적재의 프로그램적 selection은 여길 안 탄다.
        // 개별 리스트 id는 수집하지 않는다 — 스코프 종류만.
        analytics.log(.reminderScopeSelected(scope: "list"))
    }

    /// 시스템 필터(오늘/예정/전체)로 전환한다. 사용자 리스트 selection은 해제된다.
    func selectFilter(_ filter: SystemFilter) {
        selection = .systemFilter(filter)
        loadSortSettingsInBackground()
        analytics.log(.reminderScopeSelected(scope: filter.rawValue))
    }

    func toggle(_ reminder: Reminder) async {
        do {
            try await toggleCompletionUseCase(reminder)
            // 방향별로 구분 기록 — 완료는 채널(source)까지, 해제는 앱에서만 가능하니 무파라미터.
            if !reminder.isCompleted {
                analytics.log(.reminderCompleted(source: "app"))
            } else {
                analytics.log(.reminderUncompleted)
            }
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
            errorMessage = String(localized: "Select a list first.")
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
            analytics.log(.reminderCreated)
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 새 미리알림이 어느 리스트로 저장될지 결정한다.
    /// - 사용자 리스트가 selection이면 그 리스트로.
    /// - 시스템 필터 selection(오늘/예정/전체)이면 기본 목록(isDefault) 우선,
    ///   없으면 `lists.first`로 fallback. (기본 목록 이름은 로케일에 따라 다르므로 플래그로 판별.)
    private func resolveTargetListID() -> String? {
        if let selectedListID { return selectedListID }
        if let defaultList = lists.first(where: { $0.isDefault }) { return defaultList.id }
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
            analytics.log(.reminderUpdated)
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 항목을 삭제한다.
    func delete(_ reminder: Reminder) async {
        do {
            try await deleteReminderUseCase(reminderID: reminder.id)
            analytics.log(.reminderDeleted)
            try await reloadReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 새 리스트 생성 — 만들고 나서 그 리스트로 자동 전환한다.
    func addList(title: String, colorHex: String?) async {
        do {
            let newID = try await addReminderListUseCase(title: title, colorHex: colorHex)
            analytics.log(.reminderListCreated)
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
            analytics.log(.reminderListUpdated)
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
            analytics.log(.reminderListDeleted)
            lists = try await fetchListsUseCase()
            allReminders = try await fetchRemindersUseCase()
            if selectedListID == listID {
                selection = lists.first.map { .list($0.id) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// 옵션 메뉴의 "완료된 항목 보기" 토글 — 상태 전환 + 결과 상태 기록.
    /// (뷰가 `showsCompleted`를 직접 뒤집는 대신 이 메서드를 거쳐 로깅을 한곳에 모은다.)
    func toggleShowsCompleted() {
        showsCompleted.toggle()
        analytics.log(.reminderShowCompletedToggled(on: showsCompleted))
    }

    /// 좌상단 "미리 알림" 버튼 — 외부 앱 점프 직전에 뷰가 호출하는 로깅 훅.
    func logRemindersAppOpened() {
        analytics.log(.externalAppOpened(app: "reminders"))
    }

    /// 접근 거부 화면의 "설정 열기" — 설정 앱 이동 직전에 뷰가 호출하는 로깅 훅.
    func logPermissionSettingsOpened() {
        analytics.log(.permissionSettingsOpened(kind: "reminder"))
    }
}
