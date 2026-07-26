//
//  FocusViewModel.swift
//  cue / Presentation
//

import AlarmKit
import ActivityKit
import Foundation
import Observation

/// 집중 탭의 ViewModel.
///
/// **세션 프리셋**(`sessions`)을 들고 사용자가 고른 세션을 메인 화면 ring·타이틀에 반영한다.
/// 프리셋 목록과 마지막 선택은 영속화돼 재시작 후에도 같은 세션이 떠 있다.
///
/// **진행 중 세션은 AlarmKit이 단일 엔진**이다 — "시작"이 선택 세션 설정으로 단계별 알람을 예약하고,
/// 잠금화면·Dynamic Island 카운트다운 LA + 경계 알림 + 단계 전환을 시스템이 구동한다(앱이 죽어도
/// 시스템 소유라 발화).
///
/// **표시 상태는 VM이 권위 있게 들고 즉시 갱신한다** — 인앱 버튼(시작·일시정지·재개·스킵·종료)은
/// 누른 즉시 VM 상태를 바꿔 ring이 바로 반응한다. `Activity.content.state`는 같은 프로세스에서
/// 즉시 신선해지지 않으므로(백그라운드 왕복 필요) 라이브 표시의 source로 쓰지 않는다. 대신
/// `alarmUpdates`의 `Alarm.state`(신뢰 가능)로 잠금화면에서 누른 일시정지/재개/전환을 반영하고,
/// 포그라운드 복귀(`refresh`)·재실행(`onAppear`)에선 `Activity`를 한 번 읽어 백그라운드에서 바뀐
/// 단계를 채택한다.
@MainActor
@Observable
final class FocusViewModel {
    private(set) var sessions: [FocusSession] = []
    var selectedSessionID: UUID?

    // MARK: - 진행 중 세션 상태 (VM 권위 — 메인 ring/컨트롤이 읽음)

    private(set) var isActive = false
    private(set) var phase: FocusPhase = .focus
    private(set) var remaining: TimeInterval = 0
    private(set) var phaseDuration: TimeInterval = 0
    private(set) var currentCycle = 1
    private(set) var totalCycles = 1
    private(set) var isPaused = false

    // MARK: - 설정에서 읽는 토글 (onAppear에 동기화)

    /// 단계 종료 알림 소리를 낼지 — `start()`가 `FocusAlarmPlan`에 굳혀 보낸다. 기본 무음.
    private var soundEnabled = false

    /// 현재 단계 종료 시각(running). 매초 `remaining = fireDate - now` 재계산의 기준.
    private var fireDate: Date?
    /// 일시정지 시점의 잔여 — 재개 때 `fireDate = now + frozenRemaining`로 이어붙인다.
    private var frozenRemaining: TimeInterval = 0
    /// 현재 진행 중 알람 id — 일시정지/재개/종료 제어 대상.
    private var currentAlarmID: UUID?
    /// 단계 전환 중(이전 알람 취소 ~ 새 알람 예약 완료) 표시. 이 창에서 `alarmUpdates`·
    /// `adoptFromActivity`가 "알람/Activity 없음"을 보고 세션을 꺼버리는 race를 막는다.
    private var isTransitioning = false
    private var updatesTask: Task<Void, Never>?
    private var displayTask: Task<Void, Never>?

    private let fetchFocusSessions: FetchFocusSessionsUseCase
    private let saveFocusSessions: SaveFocusSessionsUseCase
    private let fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase
    private let saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase
    private let fetchAppSettings: FetchAppSettingsUseCase
    private let analytics: any AnalyticsService

    /// 무료 사용자의 세션 프리셋 한도 — Premium이면 무제한.
    static let freeSessionLimit = 1
    /// 프리미엄 여부의 반응형 소스 — 세션 추가 게이트를 호출 시점에 판정한다(구매 즉시 반영).
    private let premiumStore: PremiumStore

    /// 알람 권한 확보 시도 후 허용 여부 반환 — AlarmKit은 시스템·기기 전용이라 테스트에서 주입해 대체한다.
    private let requestAlarmAuthorization: () async -> Bool

    init(
        dependencies: Dependencies,
        premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService()),
        requestAlarmAuthorization: (() async -> Bool)? = nil
    ) {
        self.premiumStore = premiumStore
        self.requestAlarmAuthorization = requestAlarmAuthorization ?? {
            if AlarmManager.shared.authorizationState == .notDetermined {
                _ = try? await AlarmManager.shared.requestAuthorization()
            }
            return AlarmManager.shared.authorizationState == .authorized
        }
        self.fetchFocusSessions = dependencies.fetchFocusSessions
        self.saveFocusSessions = dependencies.saveFocusSessions
        self.fetchSelectedFocusSessionID = dependencies.fetchSelectedFocusSessionID
        self.saveSelectedFocusSessionID = dependencies.saveSelectedFocusSessionID
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.analytics = dependencies.analytics
    }

    var selectedSession: FocusSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    var displayedSettings: FocusSettings {
        selectedSession?.settings ?? .default
    }

    // MARK: - 생명주기

    func onAppear() async {
        let settings = await fetchAppSettings()
        soundEnabled = settings.focusEndSound
        sessions = await fetchFocusSessions()
        await restoreSelection()
        adoptFromActivity()
        if isActive { startObserving() }
    }

    /// 포그라운드 복귀 — 백그라운드에서 잠금화면 버튼·자동 전환으로 바뀐 단계를 채택한다.
    func refresh() {
        adoptFromActivity()
        if isActive, updatesTask == nil { startObserving() }
    }

    private func restoreSelection() async {
        let storedID = await fetchSelectedFocusSessionID()
        if let storedID, sessions.contains(where: { $0.id == storedID }) {
            if isUsable(sessionID: storedID) {
                selectedSessionID = storedID
            } else if let first = sessions.first {
                // 무료 한도 밖(강등 후 잔존) 선택은 화면만 첫 세션으로 폴백하고 **저장값은
                // 보존한다** — 재구독하면 원래 선택이 그대로 돌아온다(파괴적 정리 금지).
                selectedSessionID = first.id
            }
        } else if let first = sessions.first {
            selectedSessionID = first.id
            persistSelectedID(first.id)
        } else {
            selectedSessionID = nil
        }
    }

    /// 무료 한도 안에서 사용 가능한 세션인지 — 프리미엄이면 전부, 무료면 목록 앞
    /// `freeSessionLimit`개만. 생성 게이트(addSession)와 같은 한도를 사용 게이트에도 적용해
    /// 프리미엄 시절 만든 초과 세션이 강등 후 계속 쓰이는 잔존을 막는다.
    private func isUsable(sessionID: UUID) -> Bool {
        premiumStore.isPremium
            || sessions.prefix(Self.freeSessionLimit).contains { $0.id == sessionID }
    }

    // MARK: - 세션 제어 (인앱 — 누른 즉시 VM 상태 갱신)

    func start() {
        guard !isActive else { return }
        let settings = displayedSettings
        FocusAlarmPlan(
            focusDuration: settings.focusDuration,
            restDuration: settings.restDuration,
            totalCycles: settings.totalCycles,
            sessionTitle: selectedSession?.title ?? "Cue",
            colorHex: selectedSession?.colorHex,
            soundEnabled: soundEnabled
        ).save()

        isTransitioning = true
        beginPhase(.focus, cycle: 1, duration: settings.focusDuration, totalCycles: settings.totalCycles)
        startObserving()
        Task {
            guard await requestAlarmAuthorization() else {
                // 권한 거부 — 낙관적 상태를 되돌린다(인앱 타이머만 도는 상황 방지).
                FocusAlarmPlan.clear()
                clearActive()
                analytics.log(.focusPermissionDenied)
                return
            }
            // 시작 확정(권한 획득) 후에만 기록 — 거부 롤백이 "시작"으로 집계되는 것 방지.
            analytics.log(.focusStarted)
            let scheduled = await FocusAlarmScheduling.schedule(phase: .focus, cycle: 1)
            // 예약 완료 전에 사용자가 종료했으면 방금 만든 알람을 되돌린다(고아 알람 방지).
            guard isActive else { FocusAlarmScheduling.cancelAll(); return }
            currentAlarmID = scheduled
            isTransitioning = false
        }
    }

    func stopSession() {
        analytics.log(.focusEnded(source: "app"))
        tearDownSession()
    }

    /// 마지막 단계가 끝나 세션이 자연 완주됨 — 수동 종료(focusEnded)와 구분해 focusCompleted로 기록.
    private func completeSession() {
        analytics.log(.focusCompleted)
        tearDownSession()
    }

    private func tearDownSession() {
        cancelAllFocusAlarms()
        FocusAlarmPlan.clear()
        clearActive()
    }

    func pause() {
        guard isActive, !isPaused else { return }
        analytics.log(.focusPaused(source: "app"))
        isPaused = true
        if let fire = fireDate { frozenRemaining = max(0, fire.timeIntervalSinceNow) }
        remaining = frozenRemaining
        fireDate = nil
        if let id = currentAlarmID { try? AlarmManager.shared.pause(id: id) }
    }

    func resume() {
        guard isActive, isPaused else { return }
        analytics.log(.focusResumed(source: "app"))
        isPaused = false
        fireDate = Date().addingTimeInterval(frozenRemaining)
        remaining = frozenRemaining
        if let id = currentAlarmID { try? AlarmManager.shared.resume(id: id) }
    }

    func skip() {
        analytics.log(.focusSkipped)
        advance()
    }

    // MARK: - 단계 진입/전환

    /// 현재 단계 다음으로 — 없으면 종료. 인앱 상태를 즉시 바꾸고 새 알람을 예약한다. 사용자 스킵이 쓴다.
    private func advance() {
        let plan = FocusAlarmPlan.load()
        let total = plan?.totalCycles ?? totalCycles
        let next = FocusAlarmScheduling.nextStep(
            after: phase == .focus ? .focus : .rest,
            cycle: currentCycle,
            totalCycles: total
        )
        // 취소~새 예약 사이에 alarmUpdates·refresh가 "없음"을 채택해 세션을 꺼버리지 않게 잠근다.
        isTransitioning = true
        cancelAllFocusAlarms()
        guard let next else { completeSession(); return }
        let nextPhase: FocusPhase = next.phase == .focus ? .focus : .rest
        let duration = (next.phase == .focus ? plan?.focusDuration : plan?.restDuration) ?? phaseDuration
        beginPhase(nextPhase, cycle: next.cycle, duration: duration, totalCycles: total)
        Task {
            let scheduled = await FocusAlarmScheduling.schedule(phase: next.phase, cycle: next.cycle)
            // 예약 완료 전에 사용자가 종료했으면 방금 만든 알람을 되돌린다(고아 알람 방지).
            guard isActive else { FocusAlarmScheduling.cancelAll(); return }
            currentAlarmID = scheduled
            isTransitioning = false
        }
    }

    /// 한 단계 진입 — 표시 상태를 즉시 세팅(낙관적). 실제 알람 예약은 호출자가 Task로 이어서.
    private func beginPhase(_ phase: FocusPhase, cycle: Int, duration: TimeInterval, totalCycles: Int) {
        isActive = true
        isPaused = false
        self.phase = phase
        self.currentCycle = cycle
        self.totalCycles = totalCycles
        self.phaseDuration = duration
        self.remaining = duration
        self.fireDate = Date().addingTimeInterval(duration)
        self.frozenRemaining = duration
    }

    // MARK: - AlarmKit 관찰/동기화

    private func startObserving() {
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                self.handle(alarms)
            }
        }
        startDisplayTick()
    }

    /// `alarmUpdates` 처리 — **자동 전환은 하지 않는다.** 경계에서 AlarmKit 알림이 떠야 하므로
    /// `.alerting` 알람을 취소하지 않는다(취소하면 알림이 뜰 틈 없이 다음 단계로 넘어가버림).
    /// 현재 알람이 사라졌을 때(알림의 "다음 단계" 탭으로 새 단계가 잡혔거나 종료됨)만 인앱 상태를
    /// Activity에서 채택/정리한다. 일시정지/재개·스킵 같은 인앱 액션은 VM이 즉시 권위 반영한다.
    private func handle(_ alarms: [Alarm]) {
        guard Self.shouldAdoptAfterAlarmChange(
            isActive: isActive,
            isTransitioning: isTransitioning,
            currentAlarmID: currentAlarmID,
            alarmIDs: alarms.map(\.id)
        ) else { return }
        // 현재 알람이 사라짐(알림에서 다음 단계로 넘어갔거나 종료) → 새 단계 채택 or 정리.
        adoptFromActivity()
        if !isActive { stopObserving() }
    }

    /// `handle(_:)`의 채택 게이트 — 알람 목록 변화가 "현재 알람 소멸"을 뜻할 때만 재채택한다.
    /// - idle이거나 예약 진행 중(currentAlarmID nil)이면 무시 — "알람 없음=종료" 오판 방지.
    /// - 전환 중(isTransitioning)이면 무시 — 취소~새 예약 사이 빈 목록을 종료로 오판하는 race 방지.
    static func shouldAdoptAfterAlarmChange(
        isActive: Bool,
        isTransitioning: Bool,
        currentAlarmID: UUID?,
        alarmIDs: [UUID]
    ) -> Bool {
        guard isActive, !isTransitioning, let id = currentAlarmID else { return false }
        return !alarmIDs.contains(id)
    }

    /// 포그라운드/재실행 시 살아있는 집중 알람을 Activity에서 채택(백그라운드 전환 반영). 이 시점의
    /// `Activity.content.state`는 신선하다(프로세스가 막 활성화됨).
    private func adoptFromActivity() {
        // 전환 중엔 Activity가 잠깐 비어 있다 — 여기서 "없음=종료"를 채택하면 세션이 꺼진다.
        guard !isTransitioning else { return }
        let activities = Activity<AlarmAttributes<FocusAlarmMetadata>>.activities
        guard let activity = activities.first, let meta = activity.attributes.metadata else {
            clearActive()
            return
        }
        isActive = true
        currentAlarmID = activity.content.state.alarmID
        phase = meta.phase == .focus ? .focus : .rest
        currentCycle = meta.cycle
        totalCycles = meta.totalCycles
        switch activity.content.state.mode {
        case .countdown(let c):
            isPaused = false
            fireDate = c.fireDate
            phaseDuration = c.totalCountdownDuration
            remaining = max(0, c.fireDate.timeIntervalSinceNow)
            frozenRemaining = remaining
        case .paused(let p):
            isPaused = true
            fireDate = nil
            phaseDuration = p.totalCountdownDuration
            remaining = max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)
            frozenRemaining = remaining
        case .alert:
            fireDate = nil
            remaining = 0
        @unknown default:
            break
        }
    }

    /// 포그라운드 ring을 위해 매초 `remaining`을 다시 계산.
    private func startDisplayTick() {
        displayTask?.cancel()
        displayTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isActive, !self.isPaused, let fire = self.fireDate {
                    self.remaining = max(0, fire.timeIntervalSinceNow)
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopObserving() {
        updatesTask?.cancel(); updatesTask = nil
        displayTask?.cancel(); displayTask = nil
    }

    private func cancelAllFocusAlarms() {
        FocusAlarmScheduling.cancelAll()
    }

    private func clearActive() {
        stopObserving()
        isActive = false
        isPaused = false
        isTransitioning = false
        currentAlarmID = nil
        fireDate = nil
        remaining = 0
        currentCycle = 1
        phase = .focus
    }

    // MARK: - 세션 프리셋 CRUD

    /// 무료 한도(1개)를 넘는 추가는 `nil` — 호출처(에디터 시트)가 Premium 토스트를 띄운다.
    @discardableResult
    func addSession(title: String, settings: FocusSettings, colorHex: String) -> FocusSession? {
        guard premiumStore.isPremium || sessions.count < Self.freeSessionLimit else {
            analytics.log(.focusSessionLimitReached)
            return nil
        }
        let new = FocusSession(id: UUID(), title: title, settings: settings, colorHex: colorHex)
        sessions.append(new)
        analytics.log(.focusSessionCreated)
        persist()
        return new
    }

    func updateSession(id: UUID, title: String, settings: FocusSettings, colorHex: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index] = FocusSession(id: id, title: title, settings: settings, colorHex: colorHex)
        analytics.log(.focusSessionUpdated)
        persist()
    }

    func deleteSession(id: UUID) {
        analytics.log(.focusSessionDeleted)
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = nil
            persistSelectedID(nil)
        }
        persist()
    }

    /// 영속화 직렬 체인 — 쓰기마다 독립 Task를 던지면 실행 순서가 보장되지 않아
    /// "선택 저장"이 나중에 온 "선택 해제(nil) 저장"을 덮을 수 있다(선택 직후 삭제 레이스).
    /// 이전 쓰기를 await한 뒤 다음 쓰기를 실행해 호출 순서 = 저장 순서를 보장한다.
    @ObservationIgnored private var persistChain: Task<Void, Never>?

    private func enqueuePersist(_ operation: @escaping @Sendable () async -> Void) {
        persistChain = Task { [previous = persistChain] in
            await previous?.value
            await operation()
        }
    }

    /// 테스트용 — 지금까지 쌓인 영속화가 전부 끝날 때까지 대기(yield 타이밍 의존 제거).
    func flushPersistence() async {
        await persistChain?.value
    }

    private func persist() {
        let snapshot = sessions
        enqueuePersist { [saveFocusSessions] in await saveFocusSessions(snapshot) }
    }

    private func persistSelectedID(_ id: UUID?) {
        enqueuePersist { [saveSelectedFocusSessionID] in await saveSelectedFocusSessionID(id) }
    }

    /// 목록에서 사용자가 고른 선택만 여기로 온다 — onAppear의 프로그램적 복원은 이 경로를 타지 않는다.
    /// 무료 한도 밖 세션이면 선택하지 않고 false — 호출처(목록 시트)가 Premium 토스트를 띄운다.
    @discardableResult
    func selectSession(id: UUID) -> Bool {
        guard isUsable(sessionID: id) else {
            analytics.log(.focusSessionLimitReached)
            return false
        }
        analytics.log(.focusSessionSelected)
        selectedSessionID = id
        persistSelectedID(id)
        return true
    }
}
