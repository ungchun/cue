//
//  ScheduleMonthViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭 월간 캘린더 모드의 상태 + 동작.
///
/// - 범위: 이번 달 ±10년. 데이터는 보이는 달 근처만 그때그때 조회한다.
/// - 메모리: 보이는 달 ±2(최대 5개월)만 페이지·일정을 보관하고 밖은 축출한다.
/// - 적재: 보이는 달이 바뀌면 잠깐(디바운스) 기다렸다 보이는 달 → ±1 순으로 조회한다.
///   빠르게 넘기는 동안 지나쳐 간 달은 조회하지 않는다.
/// - 첫 페인트: 디스크 스냅샷(일정 이번 달 ±1·할일)으로 먼저 그리고 조회로 조용히 교체한다.
///   앱은 늘 이번 달에서 시작하므로 스냅샷도 마지막에 본 달이 아니라 이번 달 ±1만 남긴다.
///
/// 오프셋 0은 VM을 만들 때의 이번 달(앵커)로 고정한다 — 매번 `now()`로 계산하면 앱을 켜 둔 채
/// 달이 바뀌었을 때 제목과 이미 만든 페이지의 오프셋↔달 매핑이 어긋난다.
/// 월 화면은 에러 알럿을 띄우지 않는다 — 같은 탭의 타임라인이 이미 권한·조회 에러를 알린다.
@MainActor
@Observable
final class ScheduleMonthViewModel {
    private let currentEventsAccess: CurrentEventsAccessUseCase
    private let fetchEvents: FetchEventsUseCase
    private let observeEventsChanges: ObserveEventsChangesUseCase
    private let fetchAppSettings: FetchAppSettingsUseCase
    private let currentRemindersAccess: CurrentRemindersAccessUseCase
    private let fetchReminders: FetchRemindersUseCase
    private let fetchReminderLists: FetchReminderListsUseCase
    private let observeRemindersChanges: ObserveRemindersChangesUseCase
    private let loadMonthEventsSnapshot: LoadMonthEventsSnapshotUseCase
    private let saveMonthEventsSnapshot: SaveMonthEventsSnapshotUseCase
    private let loadRemindersSnapshot: LoadRemindersSnapshotUseCase
    private let fetchDailyWeather: FetchDailyWeatherUseCase
    /// 현재 시각 공급자 — 앵커 달과 격자의 "오늘" 기준. 테스트에서 주입.
    private let now: () -> Date
    /// 오프셋 0의 달(1일 자정) — init에서 한 번 고정한다.
    private let anchorMonthStart: Date
    /// 보이는 달이 바뀐 뒤 적재까지 기다리는 시간. 테스트는 0을 주입한다.
    private let debounce: Duration

    /// 넘길 수 있는 달 오프셋(이번 달=0) — ±10년.
    let monthOffsets: ClosedRange<Int> = -120...120
    /// 메모리에 두는 폭 — 보이는 달 ±2.
    private static let windowRadius = 2

    /// 보이는 달 — 제목·TabView 선택이 읽는 관찰 값.
    private var observedOffset = 0
    /// 같은 값의 비관찰 사본 — body에서 불리는 `page(for:)`가 읽어도 모든 페이지가 스와이프마다
    /// 다시 그려지는 의존성이 생기지 않게.
    @ObservationIgnored private var currentOffset = 0

    /// 지금 보이는 달 오프셋 — TabView selection과 바인딩. 바뀌면 윈도우 적재를 예약한다.
    var visibleOffset: Int {
        get { observedOffset }
        set {
            guard newValue != currentOffset else { return }
            currentOffset = newValue
            observedOffset = newValue
            scheduleWindowLoad()
        }
    }

    // 아래는 뷰가 직접 관찰하지 않는다 — 달 단위 관찰은 페이지 모델이 맡는다.
    private let titleFormatter: DateFormatter
    private let monthNameFormatter: DateFormatter
    /// 윈도우 안 페이지(강한 참조). 밖으로 나가면 비우고 놓는다.
    @ObservationIgnored private var pages: [Date: ScheduleMonthPageModel] = [:]
    /// 만든 페이지 전부의 약한 참조 — 뷰가 아직 붙든 페이지를 다시 윈도우에 넣을 때 같은 객체를
    /// 채우기 위함(새로 만들면 뷰가 옛 객체를 붙든 채 스피너에 머문다).
    @ObservationIgnored private var weakPages: [Date: () -> ScheduleMonthPageModel?] = [:]
    /// 달별 일정(숨김 필터 전 원본) — 숨김 설정만 바뀌면 재조회 없이 다시 만든다.
    @ObservationIgnored private var eventsByMonth: [Date: [CalendarEvent]] = [:]
    /// 조회로 확보한 달. 스냅샷으로만 그린 달·실패한 달은 없다 → 다음 적재에 조회.
    @ObservationIgnored private var fetchedMonths: Set<Date> = []
    /// 진행 중인 달 조회 — 같은 달을 겹쳐 조회하지 않게.
    @ObservationIgnored private var monthTasks: [Date: Task<Void, Never>] = [:]
    /// 앵커 ±1 중 마지막 스냅샷 저장 뒤 새로 조회된 달이 있는지 — 바뀐 게 없으면 저장하지 않게.
    @ObservationIgnored private var isSnapshotDirty = false
    /// 마감 달(1일 자정) → 그 달 할일. 마감 없는 할일은 달력에 안 걸리므로 버린다.
    @ObservationIgnored private var remindersByMonth: [Date: [Reminder]] = [:]
    @ObservationIgnored private var eventsAccess: EventsAccess = .notDetermined
    @ObservationIgnored private var hiddenCalendarIDs: Set<String> = []
    @ObservationIgnored private var hiddenReminderListIDs: Set<String> = []
    /// 설정 — 완료한 할일을 칸에 그릴지. 끄면 재구성 때 걸러 낸다(조회는 그대로).
    @ObservationIgnored private var showsCompletedReminders = true
    /// 설정 — 날짜 칸에 날씨 아이콘을 그릴지.
    @ObservationIgnored private var showsWeather = false
    /// 날(자정) → 날씨 SF Symbol 이름. 조회 실패면 이전 값을 그대로 둔다.
    @ObservationIgnored private var weatherSymbols: [Date: String] = [:]
    @ObservationIgnored private var reminderListColorHexes: [String: String] = [:]
    /// 권한·설정·할일 컨텍스트를 한 번이라도 읽었는지.
    @ObservationIgnored private var hasContext = false
    /// 스냅샷 첫 페인트는 VM 생애에 한 번 — 이후엔 메모리가 더 최신이다.
    @ObservationIgnored private var didPaintSnapshot = false
    /// 격자의 "오늘"을 계산한 날 — 날이 바뀌면 살아 있는 격자를 다시 만든다.
    @ObservationIgnored private var gridDay: Date?
    /// 진행 중인 컨텍스트 조회 — onAppear·적재·외부 변경이 겹쳐도 한 번만 돈다.
    @ObservationIgnored private var contextTask: Task<Void, Never>?
    /// 외부 변경 재적재 병합 — 일정·할일 스트림이 같은 변경에 둘 다 울려도 겹쳐 돌지 않게.
    @ObservationIgnored private var isReloading = false
    @ObservationIgnored private var needsReload = false
    /// 테스트 훅 — 끝난 외부 변경 재적재 횟수.
    @ObservationIgnored private(set) var externalReloadCount = 0
    /// 외부 변경 구독. 월 모드에 처음 들어올 때 시작해 VM 생애 동안 유지한다.
    /// `nonisolated(unsafe)`: Swift 6의 nonisolated `deinit`에서 cancel을 호출하기 위함.
    @ObservationIgnored nonisolated(unsafe) private var observeTasks: [Task<Void, Never>] = []
    /// 예약된(디바운스 중이거나 도는) 윈도우 적재. 보이는 달이 또 바뀌면 취소한다.
    @ObservationIgnored nonisolated(unsafe) private var windowTask: Task<Void, Never>?
    /// 진행 중인 날씨 조회 — 네트워크라 컨텍스트·윈도우 적재를 붙잡지 않게 따로 돈다.
    @ObservationIgnored nonisolated(unsafe) private var weatherTask: Task<Void, Never>?

    init(
        dependencies: Dependencies,
        now: @escaping () -> Date = { Date() },
        debounce: Duration = .milliseconds(150)
    ) {
        self.currentEventsAccess = dependencies.currentEventsAccess
        self.fetchEvents = dependencies.fetchEvents
        self.observeEventsChanges = dependencies.observeEventsChanges
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.currentRemindersAccess = dependencies.currentRemindersAccess
        self.fetchReminders = dependencies.fetchReminders
        self.fetchReminderLists = dependencies.fetchReminderLists
        self.observeRemindersChanges = dependencies.observeRemindersChanges
        self.loadMonthEventsSnapshot = dependencies.loadMonthEventsSnapshot
        self.saveMonthEventsSnapshot = dependencies.saveMonthEventsSnapshot
        self.loadRemindersSnapshot = dependencies.loadRemindersSnapshot
        self.fetchDailyWeather = dependencies.fetchDailyWeather
        self.now = now
        self.anchorMonthStart = Self.monthStart(containing: now())
        self.debounce = debounce
        // 제목 포매터는 하나만 — 렌더마다 만들지 않게. 로케일 템플릿이라 새 번역 문자열이 없다.
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        self.titleFormatter = formatter
        let monthName = DateFormatter()
        monthName.setLocalizedDateFormatFromTemplate("MMMM")
        self.monthNameFormatter = monthName
    }

    deinit {
        for task in observeTasks { task.cancel() }
        windowTask?.cancel()
        weatherTask?.cancel()
    }

    // MARK: - 표시

    /// 보이는 달 제목 — "2026년 11월". 화면 제목은 월·연을 나눠 그리므로 VoiceOver 라벨로 쓴다.
    var visibleMonthTitle: String {
        titleFormatter.string(from: monthStart(offset: visibleOffset))
    }

    /// 제목의 주인공 — 월 이름만("11월", "November").
    var visibleMonthName: String {
        monthNameFormatter.string(from: monthStart(offset: visibleOffset))
    }

    /// 제목 옆에 연하게 붙는 연도 — 숫자만("2026"). 로케일 템플릿 "y"는 ko에서 "2026년"이 돼
    /// 월 이름 옆에서 무거워 보여서, 연 숫자만 로케일 숫자 체계로 찍는다.
    var visibleYear: String {
        let year = Calendar.current.component(.year, from: monthStart(offset: visibleOffset))
        return year.formatted(.number.grouping(.never))
    }

    /// 보이는 달 1일 자정 — 연·월 피커 초기값.
    var visibleMonthStart: Date {
        monthStart(offset: visibleOffset)
    }

    /// 피커 범위 — 첫 달 1일 ~ 마지막 달 1일.
    var monthRange: ClosedRange<Date> {
        monthStart(offset: monthOffsets.lowerBound)...monthStart(offset: monthOffsets.upperBound)
    }

    /// 그 달 페이지 모델 — 관찰하지 않는 캐시에서 꺼내거나 만든다. 뷰 body에서 불리므로
    /// 관찰 상태를 바꾸지 않는다. 윈도우 밖 달은 보관하지 않고(약한 참조만) 돌려준다.
    func page(for offset: Int) -> ScheduleMonthPageModel {
        pageModel(
            for: monthStart(offset: offset),
            retain: abs(offset - currentOffset) <= Self.windowRadius
        )
    }

    /// 칩 탭으로 열 할일 원본 — 칩(`WidgetCalendarItem`)엔 시트가 쓸 반복·메모 등이 없어 받아 둔 할일에서 찾는다.
    /// 마감 있는 할일 전체를 들고 있어(달 윈도우와 무관) 칩이 보이는 한 찾힌다.
    func reminder(id: String) -> Reminder? {
        for reminders in remindersByMonth.values {
            if let match = reminders.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    /// 피커 Done — 그 날짜가 속한 달로 이동한다(범위 밖이면 끝 달로).
    func jump(to date: Date) {
        let months = Calendar.current.dateComponents(
            [.month], from: anchorMonthStart, to: Self.monthStart(containing: date)
        ).month ?? 0
        visibleOffset = min(max(months, monthOffsets.lowerBound), monthOffsets.upperBound)
    }

    // MARK: - 적재

    /// 월 모드 진입 시 — 권한(프롬프트 없이)·숨김 설정을 읽고 스냅샷으로 먼저 그린 뒤 할일·윈도우를 조회.
    func onAppear() async {
        await loadContext()
        startObservingChanges()
        await loadWindow()
    }

    /// 포그라운드 복귀 — 앱 밖에서 바뀐 권한·설정을 다시 읽고, 날이 바뀌었으면 오늘 표시를 맞춘다.
    /// 권한이 새로 생겼으면 빈 결과로 그려 둔 윈도우 달을 다시 조회한다. 바뀐 게 없으면 조회하지 않는다.
    func sceneDidBecomeActive() async {
        // 첫 진입 전이면 onAppear가 맡는다 — 같이 돌면 같은 컨텍스트를 두 번 읽는다.
        guard hasContext else { return }
        // 외부 변경 재적재가 돌고 있으면 한 번 더 돌게만 접는다 — 그 재적재가 컨텍스트·윈도우를 다시 읽는다.
        if isReloading {
            needsReload = true
            return
        }
        await loadContext()
        // 권한이 바뀌었으면 refreshContext가 조회 표시를 지웠다 — 비조회 달만 다시 받는다.
        await loadWindow()
    }

    /// 테스트 훅 — 예약된 윈도우 적재가 끝날 때까지 기다린다.
    func waitForWindowLoad() async {
        await windowTask?.value
    }

    /// 테스트 훅 — 진행 중인 날씨 조회가 끝날 때까지 기다린다.
    func waitForWeather() async {
        await weatherTask?.value
    }

    /// 테스트 훅 — 메모리에 보관 중인 달(페이지·일정).
    var cachedMonthStarts: Set<Date> {
        Set(pages.keys).union(eventsByMonth.keys)
    }

    private func scheduleWindowLoad() {
        windowTask?.cancel()
        let delay = debounce
        windowTask = Task { [weak self] in
            // 빠르게 넘기는 동안 지나쳐 가는 달은 조회하지 않게 잠깐 멈춘다(취소되면 sleep이 바로 끝남).
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            await self.loadWindow()
        }
    }

    /// 보이는 달 → ±1 순으로 조회하고, 앵커 ±1이 새로 받아졌으면 스냅샷으로 남긴다.
    private func loadWindow() async {
        if !hasContext { await loadContext() }
        let center = currentOffset
        evict(keeping: Set(windowStarts(around: center)))
        for start in primaryStarts(around: center) {
            // 그 사이 다른 달로 넘어갔으면 멈춘다 — 새 달은 새로 예약된 적재가 맡는다.
            guard !Task.isCancelled, center == currentOffset else { return }
            await loadMonth(start, force: false)
        }
        guard !Task.isCancelled, center == currentOffset else { return }
        await saveSnapshotIfNeeded()
    }

    /// 그 달 일정 조회 single-flight. `force`면 받아 둔 달도 다시 조회한다(외부 변경).
    private func loadMonth(_ start: Date, force: Bool) async {
        // 진행 중 조회를 기다린 호출자 여럿이 각자 새 조회를 띄우지 않게 — 빌 때까지 기다린다.
        while let running = monthTasks[start] { await running.value }
        if !force, fetchedMonths.contains(start) { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchAndApply(monthStart: start)
            // 끝나기 전에 비운다 — 기다리던 호출자가 깨어났을 때 끝난 작업을 다시 기다리며 돌지 않게.
            self.monthTasks[start] = nil
        }
        monthTasks[start] = task
        await task.value
    }

    /// 그 달 범위(1일 자정 ~ 다음 달 1일 자정)의 일정을 받아 페이지를 다시 만든다.
    private func fetchAndApply(monthStart start: Date) async {
        let events: [CalendarEvent]?
        if eventsAccess == .granted {
            events = try? await fetchEvents(from: start, to: monthEnd(after: start))
        } else {
            events = []
        }
        // 조회 중 멀리 넘어가 윈도우 밖이 됐으면 버린다 — 밖 달을 메모리에 두지 않기 위함.
        guard isInWindow(start) else { return }
        if let events {
            eventsByMonth[start] = events
            fetchedMonths.insert(start)
            if snapshotStarts.contains(start) { isSnapshotDirty = true }
        }
        // 실패면 받아 둔 일정(스냅샷, 없으면 빈 결과)으로 그린다 — 조회 표시는 안 해 다음 적재에 재시도.
        rebuild(monthStart: start)
    }

    /// 앵커 ±1이 모두 이번 세션에 조회돼 있고 그중 새로 받은 달이 있을 때만 저장한다.
    /// 먼 달을 보고 있으면 앵커 달이 축출돼 있어 저장하지 않는다 — 다음 실행의 첫 페인트는 이번 달이므로.
    private func saveSnapshotIfNeeded() async {
        guard isSnapshotDirty, eventsAccess == .granted else { return }
        let starts = snapshotStarts
        guard starts.allSatisfy({ fetchedMonths.contains($0) }) else { return }
        var months: [Date: [CalendarEvent]] = [:]
        for start in starts { months[start] = eventsByMonth[start] ?? [] }
        // 저장을 기다리는 사이 겹친 적재가 같은 내용을 또 저장하지 않게 먼저 내린다.
        isSnapshotDirty = false
        await saveMonthEventsSnapshot(MonthEventsSnapshot(months: months))
    }

    /// 윈도우 밖 페이지는 비우고 놓고, 일정 캐시도 버린다.
    private func evict(keeping window: Set<Date>) {
        for (start, page) in pages where !window.contains(start) {
            page.reset()
            pages[start] = nil
        }
        eventsByMonth = eventsByMonth.filter { window.contains($0.key) }
        fetchedMonths.formIntersection(window)
        weakPages = weakPages.filter { $0.value() != nil }
    }

    // MARK: - 컨텍스트 (권한·설정·할일)

    /// 컨텍스트 조회 single-flight.
    private func loadContext() async {
        if let task = contextTask {
            await task.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.refreshContext()
        }
        contextTask = task
        await task.value
        contextTask = nil
    }

    private func refreshContext() async {
        let previousAccess = eventsAccess
        eventsAccess = await currentEventsAccess()
        let settings = await fetchAppSettings()
        hiddenCalendarIDs = settings.hiddenCalendarIDs
        hiddenReminderListIDs = settings.hiddenReminderListIDs
        showsCompletedReminders = settings.monthShowsCompletedReminders
        showsWeather = settings.monthShowsWeather
        // 할일 권한은 묻지 않는다 — 없으면 일정만 보여 준다(월 화면이 프롬프트를 띄우면 맥락이 어긋난다).
        let remindersGranted = await currentRemindersAccess() == .granted
        if eventsAccess != previousAccess {
            // 권한이 바뀌면 받아 둔 일정은 무효 — 다시 조회한다(권한이 없으면 빈 결과).
            fetchedMonths.removeAll()
            if eventsAccess != .granted { eventsByMonth.removeAll() }
        }
        refreshGridsIfDayChanged()
        if !didPaintSnapshot {
            didPaintSnapshot = true
            await paintFromSnapshots(remindersGranted: remindersGranted)
        }
        if remindersGranted {
            // 실패는 조용히 이전 값(스냅샷 포함)으로 — 에러 알럿은 타임라인·할일 탭이 맡는다.
            if let lists = try? await fetchReminderLists() { applyListColors(lists) }
            if let reminders = try? await fetchReminders() { indexReminders(reminders) }
        } else {
            reminderListColorHexes = [:]
            remindersByMonth = [:]
        }
        hasContext = true
        // 숨김 설정·할일 변화는 받아 둔 일정으로 다시 만들면 충분하다(재조회 비용 절약).
        rebuildLoadedPages()
        refreshWeather()
    }

    // MARK: - 날씨

    /// 설정이 켜져 있으면 예보를 받아(저장소가 1시간 캐시) 칸을 다시 만든다. 꺼졌으면 지운다.
    private func refreshWeather() {
        guard showsWeather else {
            weatherTask?.cancel()
            weatherTask = nil
            guard !weatherSymbols.isEmpty else { return }
            weatherSymbols = [:]
            rebuildLoadedPages()
            return
        }
        guard weatherTask == nil else { return }
        weatherTask = Task { [weak self] in
            guard let self else { return }
            let forecast = try? await self.fetchDailyWeather()
            self.weatherTask = nil
            // 실패면 이전 값으로 둔다 — 에러는 띄우지 않는다(날씨는 곁들이는 정보).
            guard let forecast, self.showsWeather, !Task.isCancelled else { return }
            let symbols = Dictionary(
                forecast.map { ($0.date, $0.symbolName) },
                uniquingKeysWith: { first, _ in first }
            )
            guard symbols != self.weatherSymbols else { return }
            self.weatherSymbols = symbols
            self.rebuildLoadedPages()
        }
    }

    /// 첫 페인트 — 권한 있는 쪽 스냅샷만 쓴다. 조회는 뒤이어 조용히 교체한다.
    private func paintFromSnapshots(remindersGranted: Bool) async {
        var hasRemindersSnapshot = false
        if remindersGranted, let snapshot = await loadRemindersSnapshot() {
            applyListColors(snapshot.lists)
            indexReminders(snapshot.reminders)
            hasRemindersSnapshot = true
        }
        var months: [Date] = []
        if eventsAccess == .granted {
            if let snapshot = await loadMonthEventsSnapshot() {
                let window = Set(windowStarts(around: currentOffset))
                for (start, events) in snapshot.months
                where window.contains(start) && !fetchedMonths.contains(start) {
                    eventsByMonth[start] = events
                    months.append(start)
                }
            }
        } else if hasRemindersSnapshot {
            // 일정 권한이 없으면 일정은 어차피 비어 있다 — 할일 캐시만으로 보이는 달 ±1을 바로 그린다.
            months = primaryStarts(around: currentOffset)
        }
        for start in months { rebuild(monthStart: start) }
    }

    private func applyListColors(_ lists: [ReminderList]) {
        reminderListColorHexes = Dictionary(
            lists.compactMap { list in list.colorHex.map { (list.id, $0) } },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// 마감 달별로 한 번 묶어 둔다 — 달 재구성이 전체 할일(완료 이력 포함)을 매번 훑지 않게.
    private func indexReminders(_ reminders: [Reminder]) {
        var index: [Date: [Reminder]] = [:]
        for reminder in reminders {
            guard let due = reminder.dueDate else { continue }
            index[Self.monthStart(containing: due), default: []].append(reminder)
        }
        remindersByMonth = index
    }

    // MARK: - 페이지

    /// 받아 둔 일정 + 그 달 할일로 페이지 항목을 다시 만든다.
    private func rebuild(monthStart start: Date) {
        let calendar = Calendar.current
        let byDate = ScheduleMonthItemsBuilder.itemsByDay(
            events: eventsByMonth[start] ?? [],
            reminders: visibleReminders(in: start),
            reminderListColorHexes: reminderListColorHexes,
            hiddenCalendarIDs: hiddenCalendarIDs,
            hiddenReminderListIDs: hiddenReminderListIDs,
            from: start,
            to: monthEnd(after: start),
            calendar: calendar
        )
        var byDay: [Int: [WidgetCalendarItem]] = [:]
        for (date, items) in byDate {
            byDay[calendar.component(.day, from: date)] = items
        }
        let end = monthEnd(after: start)
        var weatherByDay: [Int: String] = [:]
        for (date, symbol) in weatherSymbols where date >= start && date < end {
            weatherByDay[calendar.component(.day, from: date)] = symbol
        }
        pageModel(for: start, retain: isInWindow(start)).apply(itemsByDay: byDay, weatherByDay: weatherByDay)
    }

    /// 적재된 페이지를 받아 둔 데이터로 다시 만든다 — 설정·할일·날씨만 바뀌었을 때.
    private func rebuildLoadedPages() {
        for (start, page) in pages where page.isLoaded {
            rebuild(monthStart: start)
        }
    }

    /// 그 달 할일 — 완료 숨김 설정이면 완료한 것을 뺀다.
    private func visibleReminders(in start: Date) -> [Reminder] {
        let reminders = remindersByMonth[start] ?? []
        return showsCompletedReminders ? reminders : reminders.filter { !$0.isCompleted }
    }

    private func pageModel(for start: Date, retain: Bool) -> ScheduleMonthPageModel {
        if let page = pages[start] { return page }
        let page = weakPages[start]?() ?? makePage(monthStart: start)
        if retain { pages[start] = page }
        return page
    }

    private func makePage(monthStart start: Date) -> ScheduleMonthPageModel {
        let page = ScheduleMonthPageModel(monthStart: start, now: now())
        weakPages[start] = { [weak page] in page }
        return page
    }

    /// 앱을 켜 둔 채 날이 바뀌면 살아 있는 격자의 오늘 표시를 맞춘다.
    private func refreshGridsIfDayChanged() {
        let current = now()
        let today = Calendar.current.startOfDay(for: current)
        let previous = gridDay
        gridDay = today
        guard let previous, previous != today else { return }
        for pageReference in weakPages.values {
            pageReference()?.refreshGrid(now: current)
        }
    }

    // MARK: - 외부 변경

    /// 일정·할일 변경 신호를 구독한다 — 이미 구독 중이면 건너뛴다(재진입마다 쌓이지 않게).
    private func startObservingChanges() {
        guard observeTasks.isEmpty else { return }
        observeTasks = [observe(observeEventsChanges()), observe(observeRemindersChanges())]
    }

    private func observe(_ stream: AsyncStream<Void>) -> Task<Void, Never> {
        Task { [weak self] in
            for await _ in stream {
                guard let self else { return }
                await self.handleExternalChange()
            }
        }
    }

    /// 앱이 직접 쓴 직후(일정 시트 저장·삭제) — 변경 알림을 기다리지 않고 다시 읽는다.
    /// EventKit이 할일 저장 직후의 일정 저장에 `EKEventStoreChanged`를 빠뜨리는 경우가 있어서다.
    func reloadAfterOwnWrite() async {
        await handleExternalChange()
    }

    /// 설정·할일을 다시 읽고 윈도우 달만 다시 조회한다.
    /// EventKit은 일정·할일 어느 쪽 변경이든 두 스트림을 함께 울리므로, 진행 중이면 한 번만 더 돌게 접는다.
    private func handleExternalChange() async {
        guard hasContext else { return }
        if isReloading {
            needsReload = true
            return
        }
        isReloading = true
        repeat {
            needsReload = false
            await loadContext()
            await reloadWindow()
        } while needsReload
        isReloading = false
        externalReloadCount += 1
    }

    /// 보이는 달 → ±1 → 그 밖에 받아 둔 윈도우 달 순으로 재조회. 윈도우 밖 달은 다시 오면 조회된다.
    private func reloadWindow() async {
        let center = currentOffset
        let window = windowStarts(around: center)
        evict(keeping: Set(window))
        let primary = primaryStarts(around: center)
        let others = window.filter { fetchedMonths.contains($0) && !primary.contains($0) }
        for start in primary + others {
            await loadMonth(start, force: true)
        }
        await saveSnapshotIfNeeded()
    }

    // MARK: - 날짜 계산

    /// 보관 윈도우(보이는 달 ±2, 범위 안)의 달 시작일.
    private func windowStarts(around center: Int) -> [Date] {
        let lower = max(center - Self.windowRadius, monthOffsets.lowerBound)
        let upper = min(center + Self.windowRadius, monthOffsets.upperBound)
        guard lower <= upper else { return [] }
        return (lower...upper).map { monthStart(offset: $0) }
    }

    /// 조회 순서 — 보이는 달, 이전 달, 다음 달(범위 안만).
    private func primaryStarts(around center: Int) -> [Date] {
        [center, center - 1, center + 1]
            .filter { monthOffsets.contains($0) }
            .map { monthStart(offset: $0) }
    }

    private func isInWindow(_ start: Date) -> Bool {
        windowStarts(around: currentOffset).contains(start)
    }

    /// 스냅샷 대상 — 앵커 달 ±1(보이는 달과 무관).
    private var snapshotStarts: [Date] {
        [-1, 0, 1].map { monthStart(offset: $0) }
    }

    /// 오프셋 달의 1일 자정 — 고정된 앵커 달 기준.
    private func monthStart(offset: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: offset, to: anchorMonthStart) ?? anchorMonthStart
    }

    private static func monthStart(containing date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date))
            ?? calendar.startOfDay(for: date)
    }

    private func monthEnd(after start: Date) -> Date {
        Calendar.current.date(byAdding: .month, value: 1, to: start) ?? start
    }
}
