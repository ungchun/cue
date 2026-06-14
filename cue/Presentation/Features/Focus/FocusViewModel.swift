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

    /// 현재 단계 종료 시각(running). 매초 `remaining = fireDate - now` 재계산의 기준.
    private var fireDate: Date?
    /// 일시정지 시점의 잔여 — 재개 때 `fireDate = now + frozenRemaining`로 이어붙인다.
    private var frozenRemaining: TimeInterval = 0
    /// 현재 진행 중 알람 id — 일시정지/재개/종료 제어 대상.
    private var currentAlarmID: UUID?
    private var updatesTask: Task<Void, Never>?
    private var displayTask: Task<Void, Never>?

    private let fetchFocusSessions: FetchFocusSessionsUseCase
    private let saveFocusSessions: SaveFocusSessionsUseCase
    private let fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase
    private let saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase

    init(dependencies: Dependencies) {
        self.fetchFocusSessions = dependencies.fetchFocusSessions
        self.saveFocusSessions = dependencies.saveFocusSessions
        self.fetchSelectedFocusSessionID = dependencies.fetchSelectedFocusSessionID
        self.saveSelectedFocusSessionID = dependencies.saveSelectedFocusSessionID
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
            selectedSessionID = storedID
        } else if let first = sessions.first {
            selectedSessionID = first.id
            persistSelectedID(first.id)
        } else {
            selectedSessionID = nil
        }
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
            colorHex: selectedSession?.colorHex
        ).save()

        beginPhase(.focus, cycle: 1, duration: settings.focusDuration, totalCycles: settings.totalCycles)
        startObserving()
        Task {
            await ensureAuthorized()
            guard AlarmManager.shared.authorizationState == .authorized else {
                // 권한 거부 — 낙관적 상태를 되돌린다(인앱 타이머만 도는 상황 방지).
                FocusAlarmPlan.clear()
                clearActive()
                return
            }
            currentAlarmID = await FocusAlarmScheduling.schedule(phase: .focus, cycle: 1)
        }
    }

    func stopSession() {
        cancelAllFocusAlarms()
        FocusAlarmPlan.clear()
        clearActive()
    }

    func pause() {
        guard isActive, !isPaused else { return }
        isPaused = true
        if let fire = fireDate { frozenRemaining = max(0, fire.timeIntervalSinceNow) }
        remaining = frozenRemaining
        fireDate = nil
        if let id = currentAlarmID { try? AlarmManager.shared.pause(id: id) }
    }

    func resume() {
        guard isActive, isPaused else { return }
        isPaused = false
        fireDate = Date().addingTimeInterval(frozenRemaining)
        remaining = frozenRemaining
        if let id = currentAlarmID { try? AlarmManager.shared.resume(id: id) }
    }

    func skip() {
        advance()
    }

    // MARK: - 단계 진입/전환

    /// 현재 단계 다음으로 — 없으면 종료. 인앱 상태를 즉시 바꾸고 새 알람을 예약한다.
    /// 사용자 스킵과 (포그라운드) 단계 종료 자동 전환이 공유한다.
    private func advance() {
        let plan = FocusAlarmPlan.load()
        let total = plan?.totalCycles ?? totalCycles
        let next = FocusAlarmScheduling.nextStep(
            after: phase == .focus ? .focus : .rest,
            cycle: currentCycle,
            totalCycles: total
        )
        cancelAllFocusAlarms()
        guard let next else { stopSession(); return }
        let nextPhase: FocusPhase = next.phase == .focus ? .focus : .rest
        let duration = (next.phase == .focus ? plan?.focusDuration : plan?.restDuration) ?? phaseDuration
        beginPhase(nextPhase, cycle: next.cycle, duration: duration, totalCycles: total)
        Task {
            currentAlarmID = await FocusAlarmScheduling.schedule(phase: next.phase, cycle: next.cycle)
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

    private func ensureAuthorized() async {
        if AlarmManager.shared.authorizationState == .notDetermined {
            _ = try? await AlarmManager.shared.requestAuthorization()
        }
    }

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
        // currentAlarmID가 nil이면 예약 진행 중(시작 직후)이라 아무것도 하지 않는다 —
        // 여기서 "알람 없음=종료"로 처리하면 시작하자마자 clearActive로 꺼지는 버그.
        guard isActive, let id = currentAlarmID else { return }
        if !alarms.contains(where: { $0.id == id }) {
            // 현재 알람이 사라짐(알림에서 다음 단계로 넘어갔거나 종료) → 새 단계 채택 or 정리.
            adoptFromActivity()
            if !isActive { stopObserving() }
        }
    }

    /// 포그라운드/재실행 시 살아있는 집중 알람을 Activity에서 채택(백그라운드 전환 반영). 이 시점의
    /// `Activity.content.state`는 신선하다(프로세스가 막 활성화됨).
    private func adoptFromActivity() {
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
        currentAlarmID = nil
        fireDate = nil
        remaining = 0
        currentCycle = 1
        phase = .focus
    }

    // MARK: - 세션 프리셋 CRUD

    @discardableResult
    func addSession(title: String, settings: FocusSettings, colorHex: String) -> FocusSession {
        let new = FocusSession(id: UUID(), title: title, settings: settings, colorHex: colorHex)
        sessions.append(new)
        persist()
        return new
    }

    func updateSession(id: UUID, title: String, settings: FocusSettings, colorHex: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index] = FocusSession(id: id, title: title, settings: settings, colorHex: colorHex)
        persist()
    }

    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = nil
            persistSelectedID(nil)
        }
        persist()
    }

    private func persist() {
        let snapshot = sessions
        Task { await saveFocusSessions(snapshot) }
    }

    private func persistSelectedID(_ id: UUID?) {
        Task { await saveSelectedFocusSessionID(id) }
    }

    func selectSession(id: UUID) {
        selectedSessionID = id
        persistSelectedID(id)
    }
}
