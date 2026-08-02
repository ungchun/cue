//
//  ScheduleViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭의 상태 + 동작.
///
/// 권한 요청, 신규 이벤트 시트 표시, 그리고 향후 일정 로드를 담당한다.
/// 신규 이벤트 입력 자체는 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가
/// 처리한다 — ViewModel은 시트 표시/닫힘 상태만 관리한다.
///
/// 페이지네이션: 첫 진입에 30일(`initialDays`)을 가져오고, List 바닥의 trigger row가
/// `loadMore()`를 호출하면 그 뒤로 2주(`pageDays`)씩 이어 붙인다. 중복 fetch는
/// `isLoadingMore` 가드로 차단.
@MainActor
@Observable
final class ScheduleViewModel {
    private let requestAccessUseCase: RequestEventsAccessUseCase
    private let currentAccessUseCase: CurrentEventsAccessUseCase
    private let loadSnapshotUseCase: LoadEventsSnapshotUseCase
    private let saveSnapshotUseCase: SaveEventsSnapshotUseCase
    private let fetchEventsUseCase: FetchEventsUseCase
    private let observeChangesUseCase: ObserveEventsChangesUseCase
    private let startLiveActivityUseCase: StartScheduleLiveActivityUseCase
    private let endLiveActivityUseCase: EndScheduleLiveActivityUseCase
    private let consumeLiveActivation: ConsumeLiveActivationUseCase
    private let analytics: any AnalyticsService
    /// 프리미엄 여부의 반응형 소스 — 라이브 한도 소비 시 호출 시점에 읽는다(구매 즉시 반영).
    private let premiumStore: PremiumStore
    private let fetchAppSettings: FetchAppSettingsUseCase
    /// 설정에서 숨긴 캘린더의 식별자 집합 — 이 캘린더의 이벤트는 타임라인·LA에서 제외한다.
    /// onAppear에서 설정을 읽어 채우고, 설정이 바뀌면 재적용한다.
    private var hiddenCalendarIDs: Set<String> = []
    /// 첫 진입 시 가져올 일수. 사용자 결정: 1달, 과거 미포함.
    private static let initialDays = 30
    /// 바닥 도달 시 추가로 가져올 일수. 사용자 결정: 2주.
    private static let pageDays = 14
    /// 첫 데이터 적재가 끝났는지. `onAppear`가 탭 전환마다 재호출되더라도 두 번째
    /// 이상은 첫 페이지 fetch를 건너뛴다 — 변경 스트림이 알려줄 때만 reload.
    private var hasLoaded = false
    /// 진행 중인 첫 적재 — 앱 시작 프리페치와 탭 진입 `onAppear`가 동시에 도착해도
    /// 첫 적재는 정확히 한 번만 돌도록 single-flight로 공유한다.
    private var firstLoadTask: Task<Void, Never>?
    /// 외부 변경 신호 스트림 구독. ViewModel 생애 동안 유지되며 신호가 올 때마다 fetched 범위
    /// 전체를 reload한다. 탭 전환에도 살아있어 다른 탭에서 발생한 변경을 놓치지 않는다.
    /// `nonisolated(unsafe)`: Swift 6의 nonisolated `deinit`에서 cancel을 호출하기 위함.
    nonisolated(unsafe) private var observeTask: Task<Void, Never>?

    private(set) var access: EventsAccess = .notDetermined
    /// 날짜별로 그룹핑된 이벤트. 일정 없는 날은 생략, 날짜·시작시간 오름차순.
    private(set) var eventsByDay: [DayGroup] = []
    /// 우상단 + 버튼이 띄우는 "신규 이벤트" 시트 표시 여부.
    var showingNewEvent = false
    /// row 탭이 띄우는 "이벤트 편집" 시트. nil이면 닫힘.
    /// `Identifiable`인 `CalendarEvent`를 그대로 두면 `.sheet(item:)`이 자동 binding.
    var editingEvent: CalendarEvent?

    /// 다음 페이지의 시작점. 직전 페이지의 종료 시점과 같다.
    /// `View`가 trigger row의 `.id(...)`로 이 값을 쓰면 페이지가 늘어날 때마다 row
    /// identity가 바뀌어 `onAppear`가 자동 재호출 — 사용자가 스크롤을 위→아래로 다시
    /// 움직이지 않아도 화면 안에 trigger가 머무는 한 다음 페이지가 계속 들어온다.
    private(set) var fetchedUntil: Date = Date()
    /// `loadMore()` 진행 중이면 true — trigger row가 viewport에 여러 번 들어오더라도
    /// 동시 중복 fetch를 막는다.
    private(set) var isLoadingMore = false

    /// 페이지네이션이 더 갈 수 있는지. `false`면 뷰가 바닥 trigger(스피너)를 아예 그리지
    /// 않는다 — 더 부를 데가 없는데 스피너만 도는 화면은 "로딩 중"이라는 거짓말이다.
    var canLoadMore: Bool { fetchedUntil < horizon }

    /// 조회 지평 — 오늘로부터 1년. 그 뒤 일정까지 타임라인으로 훑는 사용자는 없고,
    /// 상한이 없으면 빈 화면에서 페이지네이션이 영원히 돈다(→ `loadMore`).
    private var horizon: Date {
        let today = Calendar.current.startOfDay(for: now())
        return Calendar.current.date(byAdding: .day, value: Self.horizonDays, to: today) ?? today
    }

    private static let horizonDays = 365

    /// 현재 시각 공급자 — "종료 지난 일정 숨김" 필터의 기준. 테스트에서 고정값 주입.
    private let now: () -> Date

    init(dependencies: Dependencies, premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService()), now: @escaping () -> Date = { Date() }) {
        self.premiumStore = premiumStore
        self.requestAccessUseCase = dependencies.requestEventsAccess
        self.currentAccessUseCase = dependencies.currentEventsAccess
        self.loadSnapshotUseCase = dependencies.loadEventsSnapshot
        self.saveSnapshotUseCase = dependencies.saveEventsSnapshot
        self.fetchEventsUseCase = dependencies.fetchEvents
        self.observeChangesUseCase = dependencies.observeEventsChanges
        self.startLiveActivityUseCase = dependencies.startScheduleLiveActivity
        self.endLiveActivityUseCase = dependencies.endScheduleLiveActivity
        self.consumeLiveActivation = dependencies.consumeLiveActivation
        self.analytics = dependencies.analytics
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.now = now
        startObservingChanges()
    }

    /// 화면이 나타날 때 호출. 첫 진입에만 첫 페이지를 로드한다. 외부 변경 구독은 init이
    /// 시작한 별도 Task가 담당 — 탭 전환에도 살아있다.
    func onAppear() async {
        access = await requestAccessUseCase()
        guard access == .granted else { return }
        // 볼 캘린더 설정을 매 진입마다 읽는다 — 설정 탭에서 바꾸고 돌아온 경우 즉시 반영하기 위함.
        let hidden = await fetchAppSettings().hiddenCalendarIDs
        if !hasLoaded {
            hiddenCalendarIDs = hidden
            await ensureFirstLoad()
        } else if hidden != hiddenCalendarIDs {
            // 숨김 설정이 바뀌었으면 지금까지 본 범위를 다시 필터링해 반영한다.
            hiddenCalendarIDs = hidden
            await reloadFetchedRange()
        }
    }

    /// 앱 시작 프리페치 — 탭 진입을 기다리지 않고 첫 페이지 적재를 미리 끝낸다.
    /// 권한 프롬프트를 절대 유발하지 않는다: 이미 허용된 경우에만 진행하고,
    /// 미결정이면 아무것도 하지 않아 첫 탭 진입 시 기존 프롬프트 흐름이 그대로 남는다.
    func prefetch() async {
        guard !hasLoaded else { return }
        guard await currentAccessUseCase() == .granted else { return }
        access = .granted
        hiddenCalendarIDs = await fetchAppSettings().hiddenCalendarIDs
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

    /// 첫 적재 — 유효한 캐시(fetchedUntil이 미래)가 있으면 즉시 페인트한 뒤 조용히 최신화하고,
    /// 없거나 낡았으면 기존 첫 페이지(loadInitial) 경로. 어느 쪽이든 끝나면 `hasLoaded`.
    private func performFirstLoad() async {
        let nowDate = now()
        if let snapshot = await loadSnapshotUseCase(), snapshot.fetchedUntil > nowDate {
            eventsByDay = Self.groupByDay(visible(snapshot.events), now: nowDate)
            fetchedUntil = snapshot.fetchedUntil
            hasLoaded = true
            await reloadFetchedRange()
        } else {
            await loadInitial()
            hasLoaded = true
        }
    }

    /// 변경 신호 stream을 별도 Task로 구독한다 — view-bound가 아니라 ViewModel 생애에 묶여
    /// 다른 탭에서 발생한 변경도 놓치지 않는다. 신호는 첫 적재 후, 권한이 있을 때만 reload로
    /// 이어진다 — init 시점이나 권한 없을 때 emit돼도 무시된다.
    private func startObservingChanges() {
        let stream = observeChangesUseCase()
        observeTask = Task { [weak self] in
            for await _ in stream {
                await self?.handleExternalChange()
            }
        }
    }

    /// 외부 변경 신호가 왔을 때 호출 — 사용자가 페이지네이션으로 본 범위 전체를 다시
    /// 가져와 그 범위 안의 변경을 반영한다. 페이지네이션 위치(`fetchedUntil`)는 유지.
    private func handleExternalChange() async {
        guard access == .granted, hasLoaded else { return }
        await reloadFetchedRange()
    }

    /// 지금까지 페이지네이션으로 본 범위(오늘 → `fetchedUntil`)를 다시 가져와 재그룹핑한다.
    /// 외부 변경 반영과 "볼 캘린더" 설정 변경 반영이 공유한다. 실패 시 기존 표시 유지.
    private func reloadFetchedRange() async {
        let nowDate = now()
        let today = Calendar.current.startOfDay(for: nowDate)
        do {
            let events = try await fetchEventsUseCase(from: today, to: fetchedUntil)
            eventsByDay = Self.groupByDay(visible(events), now: nowDate)
            // fetch 성공 결과를 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
            // 필터 전 원본을 저장해 숨김 해제 시에도 캐시가 쓸모를 잃지 않는다.
            await saveSnapshotUseCase(EventsSnapshot(events: events, fetchedUntil: fetchedUntil))
        } catch {
            // 실패 시 기존 표시 유지 — 다음 신호에 재시도.
        }
    }

    /// 숨긴 캘린더의 이벤트를 걸러낸다. 숨김이 없으면 원본 그대로.
    private func visible(_ events: [CalendarEvent]) -> [CalendarEvent] {
        hiddenCalendarIDs.isEmpty
            ? events
            : events.filter { !hiddenCalendarIDs.contains($0.calendarID) }
    }

    deinit {
        observeTask?.cancel()
    }

    /// 라이브 액티비티 활성 상태 — 동그라미 버튼의 시각 상태 + 토글 분기.
    private(set) var liveActivityActive = false
    /// 라이브 액티비티 시작 실패 등 사용자에게 알릴 에러 — View가 alert로 표시.
    var errorMessage: String?

    /// + 버튼 액션 — 신규 이벤트 시트를 연다.
    func presentNewEvent() {
        showingNewEvent = true
    }

    /// 동그라미 버튼 액션 — 라이브 액티비티 토글.
    /// 활성이면 종료. 아니면 `eventsByDay`의 모든 이벤트를 use case로 보내 게시한다 — 다가오는
    /// 일정이 없으면 use case가 `false`를 반환해 LA를 띄우지 않는다(날짜 그룹·라벨·캡은 use case가 처리).
    /// 무료 하루 한도를 먼저 소비 — `.denied`면 기존 LA를 건드리지 않는다(뷰가 Premium 토스트).
    @discardableResult
    func toggleLiveActivity() async -> LiveActivationVerdict? {
        let verdict = await consumeLiveActivation(isPremium: premiumStore.isPremium)
        // .allowed(무료 한도 내)·.unlimited(Premium) 모두 켠다 — .denied(한도 초과)만 막는다.
        if case .denied = verdict {
            analytics.log(.liveDenied(kind: "schedule"))
            return verdict
        }
        // 떠 있으면 끄고 다시 켠다(새로고침) — 더는 단순 종료하지 않는다.
        if liveActivityActive {
            await endLiveActivityUseCase()
            liveActivityActive = false
        }
        do {
            liveActivityActive = try await startLiveActivityUseCase(
                events: eventsByDay.flatMap(\.events),
                weekEvents: await fetchWeekEvents()
            )
            if !liveActivityActive { await endLiveActivityUseCase() }
            if liveActivityActive { analytics.log(.liveToggled(kind: "schedule", on: true)) }
        } catch {
            errorMessage = String(localized: "Couldn't start Live Activity.")
            return nil
        }
        return verdict
    }

    /// 이번 주(로케일 주 시작 요일 기준 7일) 캘린더 이벤트 — Dynamic Island 주간 스트립의
    /// 날짜별 점 계산용. 표시용 `eventsByDay`는 다가오는 일정만 담아 과거 날짜 점을 못 그리므로
    /// 여기서 이번 주 전체 범위를 따로 조회한다. 권한 없거나 실패면 빈 배열(점 없음).
    private func fetchWeekEvents() async -> [CalendarEvent] {
        guard access == .granted,
              let week = WeekEventDotsBuilder.weekRange(for: now()) else { return [] }
        return (try? await fetchEventsUseCase(from: week.start, to: week.end)) ?? []
    }

    /// 항상 표시 자동 게시 — 권한이 있으면 일정을 적재하고 LA 시작(다가오는 일정 없으면 use case가 skip).
    /// 사용자 탭이 아니므로 하루 쿼터를 소비하지 않는다. 이미 켜져 있으면 건너뛴다.
    func startAlwaysOnLiveActivity() async {
        // 항상 표시는 Premium 전용 — 게시 시점에 재확인(구독 만료·과거 저장값 잔존 방어).
        guard premiumStore.isPremium else { return }
        guard !liveActivityActive else { return }
        await onAppear()
        guard access == .granted else { return }
        do {
            liveActivityActive = try await startLiveActivityUseCase(
                events: eventsByDay.flatMap(\.events),
                weekEvents: await fetchWeekEvents()
            )
        } catch {
            // 자동 경로 — 조용히 무시.
        }
    }

    /// 시트의 저장·취소·삭제 콜백에서 호출 — 시트를 닫는다. 저장이면 event_created,
    /// 삭제면 event_deleted 기록(취소는 무기록).
    func dismissNewEvent(outcome: EventEditOutcome = .canceled) {
        switch outcome {
        case .saved: analytics.log(.eventCreated)
        case .deleted: analytics.log(.eventDeleted)
        case .canceled: break
        }
        showingNewEvent = false
    }

    /// 이벤트 row 탭 — 편집 시트를 연다.
    /// 구독 캘린더(공휴일 등 `isReadOnly == true`)는 EventKit이 수정을 막으므로 시트를
    /// 띄우지 않고 무시한다 — 띄워도 저장이 안 되어 사용자 혼란만 만든다.
    func presentEdit(_ event: CalendarEvent) {
        guard !event.isReadOnly else { return }
        editingEvent = event
    }

    /// 편집 시트 콜백 — 시트를 닫는다. 저장이면 event_updated, 시트 안 삭제 버튼이면
    /// event_deleted 기록(취소는 무기록).
    func dismissEdit(outcome: EventEditOutcome = .canceled) {
        switch outcome {
        case .saved: analytics.log(.eventUpdated)
        case .deleted: analytics.log(.eventDeleted)
        case .canceled: break
        }
        editingEvent = nil
    }

    /// 좌상단 캘린더 버튼 — Apple 캘린더 앱 열기를 기록한다. URL 열기 자체는 뷰의
    /// `openURL` 담당(SwiftUI 환경 핸들은 뷰 전용).
    func calendarAppOpened() {
        analytics.log(.externalAppOpened(app: "calendar"))
    }

    /// 권한 거부 화면 "설정 열기" — 설정 앱 이동을 기록한다. 열기 자체는 뷰 담당.
    func permissionSettingsOpened() {
        analytics.log(.permissionSettingsOpened(kind: "schedule"))
    }

    /// 바닥 trigger가 viewport에 들어오면 호출 — 다음 2주를 fetch해 이어 붙인다.
    /// 권한 없거나 이미 로딩 중이면 no-op. 실패 시 `fetchedUntil`을 갱신하지 않아
    /// 다음 호출에서 같은 범위로 재시도된다.
    ///
    /// 지평(`horizon`)을 넘어서면 더 부르지 않는다 — 화면이 비어 있으면 바닥 trigger가
    /// viewport에 계속 머물고, 페이지를 가져올 때마다 `fetchedUntil`이 바뀌어 trigger의
    /// identity가 갈리므로 `onAppear`가 무한히 재호출된다. 실기기에서 2041년까지 2주씩
    /// 전진하며 EventKit 조회를 끝없이 반복했다(볼 캘린더를 대부분 숨겨 결과가 늘 0건인 경우).
    func loadMore() async {
        guard access == .granted, !isLoadingMore, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let nowDate = now()
        let from = fetchedUntil
        let next = Calendar.current.date(byAdding: .day, value: Self.pageDays, to: from) ?? from
        // 마지막 페이지는 지평에서 잘린다 — 지평을 넘겨 조회하면 `canLoadMore`가 이미
        // false인데도 그 범위가 fetchedUntil에 남아 다음 판정이 흔들린다.
        let to = min(next, horizon)
        guard from < to else { return }
        do {
            let events = try await fetchEventsUseCase(from: from, to: to)
            eventsByDay = Self.merge(existing: eventsByDay, new: Self.groupByDay(visible(events), now: nowDate))
            fetchedUntil = to
        } catch {
            // fetchedUntil 유지 — 다음 호출에서 재시도.
        }
    }

    /// 첫 페이지(오늘 → +initialDays) 로드. 실패 시 빈 배열로 둔다.
    private func loadInitial() async {
        let nowDate = now()
        let today = Calendar.current.startOfDay(for: nowDate)
        let to = Calendar.current.date(
            byAdding: .day, value: Self.initialDays, to: today
        ) ?? today
        do {
            let events = try await fetchEventsUseCase(from: today, to: to)
            eventsByDay = Self.groupByDay(visible(events), now: nowDate)
            fetchedUntil = to
            // fetch 성공 결과를 스냅샷으로 저장 — 다음 실행의 첫 페인트 재료.
            await saveSnapshotUseCase(EventsSnapshot(events: events, fetchedUntil: to))
        } catch {
            eventsByDay = []
        }
    }

    /// 이벤트들을 시작일의 캘린더 자정으로 묶고, 그룹은 날짜 오름차순, 그룹 내부는
    /// 시작 시간 오름차순으로 정렬한다.
    ///
    /// 오늘 자정(`startOfDay(now)`)보다 이른 시작일은 오늘로 끌어올린다 — 여러 날 걸친
    /// 일정이 과거에 시작했어도 오늘 진행 중이면 지난 날짜 헤더가 아니라 오늘 그룹에 묶인다.
    ///
    /// **종료 시간이 지난 시간 이벤트는 오늘이라도 숨긴다**(`endDate >= now`) — 종일은 시간
    /// 무관하게 유지. LA(`StartScheduleLiveActivityUseCase.groupIntoDays`)와 동일 기준.
    static func groupByDay(_ events: [CalendarEvent], now: Date) -> [DayGroup] {
        let calendar = Calendar.current
        let floor = calendar.startOfDay(for: now)
        let visible = events.filter { $0.isAllDay || $0.endDate >= now }
        let buckets = Dictionary(grouping: visible) { event in
            max(calendar.startOfDay(for: event.startDate), floor)
        }
        return buckets
            .map { date, events in
                DayGroup(date: date, events: events.sorted { $0.startDate < $1.startDate })
            }
            .sorted { $0.date < $1.date }
    }

    /// 기존 그룹들에 새 그룹들을 병합한다. 같은 날짜의 이벤트는 합치고, id 중복은 제거,
    /// 그룹 내부는 시작 시간 오름차순, 그룹은 날짜 오름차순.
    static func merge(existing: [DayGroup], new: [DayGroup]) -> [DayGroup] {
        var byDate: [Date: [CalendarEvent]] = [:]
        for group in existing {
            byDate[group.date] = group.events
        }
        for group in new {
            byDate[group.date, default: []].append(contentsOf: group.events)
        }
        return byDate
            .map { date, events in
                var seenIDs: Set<String> = []
                let unique = events.filter { seenIDs.insert($0.id).inserted }
                return DayGroup(date: date, events: unique.sorted { $0.startDate < $1.startDate })
            }
            .sorted { $0.date < $1.date }
    }
}

/// 타임라인 한 섹션 — 한 날짜와 그날의 이벤트들.
struct DayGroup: Identifiable, Equatable, Sendable {
    /// 그날의 캘린더 자정 (`Calendar.startOfDay`)
    let date: Date
    let events: [CalendarEvent]

    var id: Date { date }
}
