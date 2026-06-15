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
    private let startLiveActivityUseCase: StartReminderLiveActivityUseCase
    private let endLiveActivityUseCase: EndReminderLiveActivityUseCase

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
        self.startLiveActivityUseCase = dependencies.startReminderLiveActivity
        self.endLiveActivityUseCase = dependencies.endReminderLiveActivity
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
    func toggleLiveActivity(listTitle: String) async {
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
            return
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
    /// - `.list(id)`: 그 리스트의 미완료. **시간 지정 없는 항목**(`dueDate == nil`
    ///   또는 `includesTime == false`)이 위, 그 아래는 dueDate 오름차순.
    /// - `.systemFilter(.today)`: 오늘 자정 이전 마감(overdue 포함) 미완료, dueDate asc.
    /// - `.systemFilter(.scheduled)`: 마감일이 있는 모든 미완료, dueDate asc.
    /// - `.systemFilter(.all)`: 모든 미완료, dueDate asc(nil 뒤).
    var visibleReminders: [Reminder] {
        let incomplete = allReminders.filter { !$0.isCompleted }
        switch selection {
        case .list(let id):
            return incomplete
                .filter { $0.listID == id }
                .sorted(by: untimedFirstThenAscending)
        case .systemFilter(.today):
            // 오늘 자정(다음날 0시) 이전 마감이면 모두 포함 — overdue + 오늘 마감.
            let tomorrowMidnight = Calendar.current.startOfDay(for: Date())
                .addingTimeInterval(24 * 60 * 60)
            return incomplete
                .filter { guard let due = $0.dueDate else { return false }
                          return due < tomorrowMidnight }
                .sorted(by: dueDateAscendingNilLast)
        case .systemFilter(.scheduled):
            return incomplete
                .filter { $0.dueDate != nil }
                .sorted(by: dueDateAscendingNilLast)
        case .systemFilter(.all):
            return incomplete.sorted(by: dueDateAscendingNilLast)
        case .none:
            return []
        }
    }

    /// 시간 지정 없는 항목(시각 미설정 또는 마감 없음)을 위로, 시간 지정 항목은
    /// 그 아래 dueDate 오름차순.
    private func untimedFirstThenAscending(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        let lhsTimed = lhs.dueDate != nil && lhs.includesTime
        let rhsTimed = rhs.dueDate != nil && rhs.includesTime
        if lhsTimed != rhsTimed { return !lhsTimed }     // 시간 없음 먼저
        if !lhsTimed { return false }                    // 둘 다 시간 없음 — 원순 보존
        return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    }

    /// dueDate 오름차순. nil은 `distantFuture`로 취급해 맨 뒤로.
    private func dueDateAscendingNilLast(_ lhs: Reminder, _ rhs: Reminder) -> Bool {
        (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    }

    /// `.all` 모드에서 본문에 그릴 (리스트, 미완료, 완료) 묶음.
    /// 리스트 표시 순서는 `lists`와 동일하고, 미완료는 시간 지정 없는 항목이 위
    /// 그 아래 dueDate 오름차순. 완료 항목은 EventKit 원본 순서(다른 모드의
    /// `completedReminders`와 동일 처리) — `showsCompleted` OFF면 빈 배열.
    /// 빈 리스트도 포함한다(섹션 헤더는 보여야 하므로).
    var allModeSections: [(list: ReminderList, active: [Reminder], completed: [Reminder])] {
        lists.map { list in
            let active = allReminders
                .filter { $0.listID == list.id && !$0.isCompleted }
                .sorted(by: untimedFirstThenAscending)
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
    }

    /// 시스템 필터(오늘/예정/전체)로 전환한다. 사용자 리스트 selection은 해제된다.
    func selectFilter(_ filter: SystemFilter) {
        selection = .systemFilter(filter)
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
