//
//  FocusSessionViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 진행 중인 집중 세션의 상태머신.
///
/// 단계(`focus`/`rest`) · 종료 deadline(`phaseEndDate`) · 현재 사이클을 들고 있다.
/// `remaining`은 `phaseEndDate - now`로 매 tick **재계산되는 파생값**이다 — 직접 감산하지
/// 않는다(정수 counter drift, 백그라운드 추격 점프 방지). 뷰는 `Timer.publish`로 1초마다,
/// 백그라운드 복귀 시 한 번 `tick()`을 부른다. `phaseEndDate`는 라이브 액티비티에도 그대로
/// 넘겨 **앱·LA가 같은 deadline을 읽게 하는 single source of truth**다.
///
/// 단계 종료 알림은 `FocusNotificationScheduling`에 위임 — 한 번에 하나의 pending 알림만
/// 유지하고, 단계 전환·일시정지·스킵·중단 직전에 `cancelAll()`로 비운 뒤 다음 단계의
/// `schedulePhaseEnd()`를 다시 잡는다.
@MainActor
@Observable
final class FocusSessionViewModel {
    /// 세션의 원본 설정 — `tick` 처리 도중 단계가 바뀔 때 다음 단계 길이의 출처가 된다.
    private let settings: FocusSettings
    private let scheduler: any FocusNotificationScheduling
    /// 라이브 액티비티 hooks — nil이면 LA 호출을 모두 건너뛴다(테스트·Preview).
    /// 세션 시작 시 `start`, phase 전환·pause/resume에서 `update`, 종료 시 `end`, 복원 시 `restore`.
    private let liveActivity: LiveActivityHooks?
    /// 현재 시각 provider — 테스트에서 결정적 clock을 주입하려고 추상화. 기본은 `Date.now`.
    /// 모든 시각 계산(deadline·remaining·pauseTime)이 이 하나만 읽는다.
    private let now: () -> Date
    /// 진행 중 세션 스냅샷 영속화 hook. nil이면 영속 생략(테스트·Preview). 구조적 상태가
    /// 바뀔 때(시작·단계 전환·정지·재개)마다 최신 스냅샷을, 종료·완료 시 nil(삭제)을 받는다.
    /// 매 tick은 부르지 않는다 — running의 잔여는 `phaseEndDate`(이미 저장됨)에서 파생되므로.
    private let persist: (@Sendable (ActiveFocusSessionSnapshot?) -> Void)?

    /// 세션 식별자 — 스냅샷 영속과 LA 호출에 함께 쓰인다.
    let sessionID: UUID
    /// LA·스냅샷에 싣는 표시 타이틀.
    let sessionTitle: String
    /// 세션 색 hex. widget이 아이콘 등에 사용. nil이면 시스템 accent로 폴백.
    let colorHex: String?

    /// 세션과 라이브 액티비티를 연결하는 use case 묶음. `FocusViewModel`이 만들어 주입.
    /// 식별자·타이틀·색은 ViewModel이 직접 들고(스냅샷에도 필요) hooks엔 use case만 둔다.
    struct LiveActivityHooks: Sendable {
        let start: StartFocusLiveActivityUseCase
        let update: UpdateFocusLiveActivityUseCase
        let end: EndFocusLiveActivityUseCase
        /// 앱 재실행 복원 — 기존 인스턴스 채택 또는 새로 시작.
        let restore: RestoreFocusLiveActivityUseCase
    }

    /// 현재 단계.
    private(set) var phase: FocusPhase = .focus
    /// 현재 phase의 시작 시각 — 라이브 액티비티 timer interval의 안정적 lowerBound로 사용.
    /// pause 동안엔 그대로, resume·phase 전환 시 갱신해 interval 길이를 phaseDuration으로 유지.
    private(set) var phaseStartDate: Date
    /// 현재 phase의 종료 deadline(절대 시각) — **앱·라이브 액티비티 공통 source of truth**.
    /// `remaining`은 이 값에서 벽시계를 빼 재계산되고, LA에도 그대로 넘겨 둘이 같은 deadline을
    /// 읽게 한다. resume·phase 전환·skip에서 갱신.
    private(set) var phaseEndDate: Date
    /// 현재 단계의 남은 시간(초). `tick`마다 `phaseEndDate - now`로 다시 박고, pause면 멈춘다.
    /// **deadline 파생값** — 직접 감산하지 않는다(counter drift·백그라운드 추격 점프 방지).
    private(set) var remaining: TimeInterval
    /// 현재 사이클 번호 — 1부터 시작해 한 사이클(집중→휴식)이 끝나면 +1.
    private(set) var currentCycle: Int = 1
    /// 진행 표시(`1 / N`)와 종료 판정에 쓰이는 총 사이클 수.
    let totalCycles: Int
    /// 일시정지 여부. true면 `tick`이 무시된다.
    private(set) var isPaused: Bool = false
    /// 세션이 끝났는지 — 마지막 집중 종료 후 true. 이후엔 `tick`이 무시된다.
    private(set) var isComplete: Bool = false

    /// 현재 단계의 전체 길이 — 뷰가 원형 progress 비율을 계산할 때 분모로 쓴다.
    var phaseDuration: TimeInterval {
        phase == .focus ? settings.focusDuration : settings.restDuration
    }

    /// 새 세션 시작.
    init(
        settings: FocusSettings,
        scheduler: any FocusNotificationScheduling,
        liveActivity: LiveActivityHooks? = nil,
        now: @escaping () -> Date = { .now },
        sessionID: UUID = UUID(),
        sessionTitle: String = "",
        colorHex: String? = nil,
        persist: (@Sendable (ActiveFocusSessionSnapshot?) -> Void)? = nil
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.liveActivity = liveActivity
        self.now = now
        self.sessionID = sessionID
        self.sessionTitle = sessionTitle
        self.colorHex = colorHex
        self.persist = persist
        let phaseStart = now()
        let phaseEnd = phaseStart.addingTimeInterval(settings.focusDuration)
        self.phaseStartDate = phaseStart
        self.phaseEndDate = phaseEnd
        self.remaining = settings.focusDuration
        self.totalCycles = settings.totalCycles
        scheduler.schedulePhaseEnd(
            after: settings.focusDuration,
            title: Self.title(for: .focus),
            body: Self.body(for: .focus)
        )
        persistSnapshot()
        // 세션 시작 = LA start. Task 안에선 capture 값만 — self capture 회피.
        if let hooks = liveActivity {
            let id = sessionID, title = sessionTitle, color = colorHex
            Task {
                try? await hooks.start(
                    sessionID: id,
                    sessionTitle: title,
                    colorHex: color,
                    phase: .focus,
                    phaseStartDate: phaseStart,
                    phaseEndDate: phaseEnd
                )
            }
        }
    }

    /// 진행 중이던 세션을 스냅샷에서 복원(앱 강제 종료 후 재실행). 새 LA를 start하지 않고
    /// `restore`로 기존 인스턴스를 채택하거나 없으면 새로 띄운다. 시간은 절대 시각 기반이라
    /// 복원 직후 `tick()` 한 번이면 다운타임만큼 벽시계로 정확히 따라잡는다.
    init(
        restoring snapshot: ActiveFocusSessionSnapshot,
        scheduler: any FocusNotificationScheduling,
        liveActivity: LiveActivityHooks? = nil,
        now: @escaping () -> Date = { .now },
        persist: (@Sendable (ActiveFocusSessionSnapshot?) -> Void)? = nil
    ) {
        self.settings = snapshot.settings
        self.scheduler = scheduler
        self.liveActivity = liveActivity
        self.now = now
        self.sessionID = snapshot.sessionID
        self.sessionTitle = snapshot.sessionTitle
        self.colorHex = snapshot.colorHex
        self.persist = persist
        self.phase = snapshot.phase
        self.currentCycle = snapshot.currentCycle
        self.totalCycles = snapshot.settings.totalCycles
        self.isPaused = snapshot.isPaused

        // 모든 저장 프로퍼티 초기화 전엔 self 프로퍼티를 못 읽으므로 로컬로 계산 후 한 번에 대입.
        let resolvedStart: Date
        let resolvedEnd: Date
        let resolvedRemaining: TimeInterval
        if snapshot.isPaused {
            // 정지 — 잔여를 source of truth로, deadline은 now 기준 재구성(재개 시 정확).
            let phaseDur = snapshot.phase == .focus ? snapshot.settings.focusDuration : snapshot.settings.restDuration
            resolvedRemaining = snapshot.remaining
            resolvedEnd = now().addingTimeInterval(snapshot.remaining)
            resolvedStart = resolvedEnd.addingTimeInterval(-phaseDur)
        } else {
            // running — 절대 deadline 그대로.
            resolvedStart = snapshot.phaseStartDate
            resolvedEnd = snapshot.phaseEndDate
            resolvedRemaining = max(0, snapshot.phaseEndDate.timeIntervalSince(now()))
        }
        self.phaseStartDate = resolvedStart
        self.phaseEndDate = resolvedEnd
        self.remaining = resolvedRemaining

        // running이면 단계 종료 알림을 실제 남은 시각으로 재예약(정지는 재개 시 예약).
        if !snapshot.isPaused {
            scheduler.schedulePhaseEnd(
                after: max(1, resolvedRemaining),
                title: Self.title(for: snapshot.phase),
                body: Self.body(for: snapshot.phase)
            )
        }

        let phaseSnapshot: LiveFocusPhase = snapshot.phase == .focus ? .focus : .breakTime
        let start = resolvedStart, end = resolvedEnd
        let pauseTime: Date? = snapshot.isPaused ? now() : nil
        if let hooks = liveActivity {
            let id = sessionID, title = sessionTitle, color = colorHex
            Task {
                try? await hooks.restore(
                    sessionID: id,
                    sessionTitle: title,
                    colorHex: color,
                    phase: phaseSnapshot,
                    phaseStartDate: start,
                    phaseEndDate: end,
                    pauseTime: pauseTime
                )
            }
        }
    }

    // MARK: - tick

    /// 벽시계 기준으로 상태를 재평가한다. 뷰의 `Timer.publish`가 1초마다, 백그라운드 복귀 시
    /// 한 번 부른다. 인자가 없다 — 흘러간 시간은 주입된 clock(`now`)이 안다.
    ///
    /// deadline(`phaseEndDate`)이 지났으면 지난 경계마다 단계를 캐스케이드 전환하고,
    /// `remaining`을 `phaseEndDate - now`로 다시 박는다. 백그라운드에서 여러 단계가 지나도
    /// 단 한 번의 호출로 정확히 착지한다 — counter 추격 tick이 없어 '초가 확확 줄어드는'
    /// 점프가 사라지고, 같은 deadline을 읽는 LA와 항상 일치한다.
    func tick() {
        guard !isPaused, !isComplete else { return }
        while !isComplete, now() >= phaseEndDate {
            advancePhase()
        }
        if !isComplete {
            remaining = max(0, phaseEndDate.timeIntervalSince(now()))
        }
    }

    // MARK: - 사용자 액션

    /// 일시정지 — 앱 내 컨트롤용. 지금 시각 기준으로 멈춘다.
    func pause() { pause(at: now()) }

    /// 일시정지(누른 시각 지정) — LA 버튼이 drain될 때 **누른 시각**(`date`)을 넘겨, drain이
    /// 늦어도 그 시점 기준으로 freeze해 시간 누수를 막는다. `remaining`을 `phaseEndDate - date`로
    /// 박고, 단계 종료 pending 알림 취소. LA는 같은 `phaseEndDate` + `pauseTime = date`를 받아
    /// 정지 표시(`phaseEndDate - date`)가 앱 `remaining`과 정확히 일치한다.
    func pause(at date: Date) {
        guard !isPaused, !isComplete else { return }
        // phaseDuration으로 상한 클램프 — 잔여는 단계 길이를 넘을 수 없다. 늦은/엉뚱한 `date`
        // (예: 잔재 액션의 과거 시각)가 잔여를 부풀리는 걸 방어한다.
        remaining = min(phaseDuration, max(0, phaseEndDate.timeIntervalSince(date)))
        isPaused = true
        scheduler.cancelAll()
        scheduleLiveActivityUpdate(pauseTime: date)
        persistSnapshot()
    }

    /// 재개 — 앱 내 컨트롤용. 지금 시각 기준으로 다시 시작한다.
    func resume() { resume(at: now()) }

    /// 재개(누른 시각 지정) — **누른 시각**(`date`) 기준으로 deadline을 재구성한다.
    /// `phaseEndDate = date + remaining`, `phaseStartDate = phaseEndDate - phaseDuration`으로
    /// interval 길이를 유지하고 `pauseTime` 해제. drain이 누른 시각보다 늦으면 그 사이 흐른
    /// 시간은 정상적으로 카운트다운된다(누른 순간부터 타이머가 도는 것). 알림은 실제 남은
    /// 시각(`phaseEndDate - now`)으로 잡아 늦은 drain을 보정. 앱·LA가 동일 deadline을 공유.
    func resume(at date: Date) {
        guard isPaused, !isComplete else { return }
        isPaused = false
        phaseEndDate = date.addingTimeInterval(remaining)
        phaseStartDate = phaseEndDate.addingTimeInterval(-phaseDuration)
        scheduler.schedulePhaseEnd(
            after: max(0, phaseEndDate.timeIntervalSince(now())),
            title: Self.title(for: phase),
            body: Self.body(for: phase)
        )
        scheduleLiveActivityUpdate(pauseTime: nil)
        persistSnapshot()
    }

    /// 현재 단계를 즉시 끝낸 것으로 처리하고 다음 단계로 넘긴다(혹은 세션 종료).
    /// deadline을 지금으로 당겨 `advancePhase`가 그 경계에서 다음 단계를 잇게 한다.
    func skip() {
        guard !isComplete else { return }
        isPaused = false
        phaseEndDate = now()
        advancePhase()
    }

    /// 세션을 강제 종료 — `isComplete = true`로 두고 pending 알림을 비운다.
    /// 뷰는 `isComplete` 관찰로 시트를 닫는다. 라이브 액티비티도 함께 종료(60초 후 dismiss).
    func abort() {
        guard !isComplete else { return }
        isComplete = true
        scheduler.cancelAll()
        scheduleLiveActivityEnd()
        clearSnapshot()
    }

    // MARK: - 내부 — 단계 전환

    /// 현재 단계가 끝났을 때 호출. 다음 단계(또는 종료)로 상태를 옮기고 다음 알림을 잡는다.
    /// 단계 종료 시점이라 `remaining`은 진입 시 0이며, 다음 단계로 이동하면서 새 길이로
    /// 재설정된다.
    private func advancePhase() {
        scheduler.cancelAll()
        // 방금 지난 deadline을 다음 단계의 시작 경계로 — 백그라운드로 여러 단계가 한꺼번에
        // 지나도 `.now`가 아니라 경계에서 이어붙여 캐스케이드가 정확하다.
        let boundary = phaseEndDate
        switch phase {
        case .focus:
            // 반복 OFF거나 마지막 사이클의 집중이 끝나면 세션 종료(휴식 없음).
            if !settings.isRepeating || currentCycle >= totalCycles {
                isComplete = true
                remaining = 0
                scheduleLiveActivityEnd()
                clearSnapshot()
                return
            }
            phase = .rest
            phaseStartDate = boundary
            phaseEndDate = boundary.addingTimeInterval(settings.restDuration)
        case .rest:
            // 휴식이 끝나면 다음 사이클의 집중으로.
            currentCycle += 1
            phase = .focus
            phaseStartDate = boundary
            phaseEndDate = boundary.addingTimeInterval(settings.focusDuration)
        }
        // 남은 알림 시각은 새 deadline까지의 실시간 — 캐스케이드 중간 단계는 0으로 박혀
        // 다음 advancePhase의 cancelAll에 지워지고, 착지 단계만 양수로 남는다.
        remaining = max(0, phaseEndDate.timeIntervalSince(now()))
        scheduler.schedulePhaseEnd(
            after: remaining,
            title: Self.title(for: phase),
            body: Self.body(for: phase)
        )
        scheduleLiveActivityUpdate(pauseTime: nil)
        persistSnapshot()
    }

    // MARK: - 스냅샷 영속

    /// 현재 상태를 스냅샷으로 떠 영속 hook에 넘긴다. hook이 nil이면 no-op.
    private func persistSnapshot() {
        guard let persist else { return }
        persist(ActiveFocusSessionSnapshot(
            sessionID: sessionID,
            sessionTitle: sessionTitle,
            colorHex: colorHex,
            settings: settings,
            phase: phase,
            currentCycle: currentCycle,
            phaseStartDate: phaseStartDate,
            phaseEndDate: phaseEndDate,
            isPaused: isPaused,
            remaining: remaining
        ))
    }

    /// 저장된 스냅샷 삭제 — 종료·완료 시. 다음 실행에서 복원할 세션이 없음을 뜻한다.
    private func clearSnapshot() {
        persist?(nil)
    }

    // MARK: - 라이브 액티비티 호출 helpers

    /// 현재 phase·deadline·pauseTime을 스냅샷 떠 LA `update`를 비동기 dispatch.
    /// `phaseEndDate`를 그대로 넘겨 앱과 LA가 같은 deadline을 읽게 한다(싱크의 핵심).
    /// hooks가 nil이면 no-op. 매초 호출 금지 — phase 전환/pause/resume에서만 부른다.
    private func scheduleLiveActivityUpdate(pauseTime: Date?) {
        guard let hooks = liveActivity else { return }
        let phaseSnapshot = liveFocusPhase
        let startSnapshot = phaseStartDate
        let endSnapshot = phaseEndDate
        Task {
            try? await hooks.update(
                phase: phaseSnapshot,
                phaseStartDate: startSnapshot,
                phaseEndDate: endSnapshot,
                pauseTime: pauseTime
            )
        }
    }

    /// LA `end`를 비동기 dispatch. hooks가 nil이면 no-op.
    /// dismissalPolicy는 service 구현이 결정(`.after(now + 60s)` — 완료 결과 잠깐 노출).
    private func scheduleLiveActivityEnd() {
        guard let hooks = liveActivity else { return }
        Task {
            await hooks.end()
        }
    }

    /// FocusPhase → LiveFocusPhase 매핑. 표시 schema는 별도이므로 의미적 매핑만.
    private var liveFocusPhase: LiveFocusPhase {
        switch phase {
        case .focus: return .focus
        case .rest: return .breakTime
        }
    }

    // MARK: - 알림 문구

    /// 단계 종료 알림 제목 — 단계가 *끝났음*을 알린다(다음 단계 시작이 아니라).
    private static func title(for phase: FocusPhase) -> String {
        switch phase {
        case .focus: "집중 완료"
        case .rest: "휴식 끝"
        }
    }

    /// 단계 종료 알림 본문.
    private static func body(for phase: FocusPhase) -> String {
        switch phase {
        case .focus: "잠시 쉬어가요."
        case .rest: "다시 집중해 볼까요."
        }
    }
}
