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
    /// 세션 시작 시 `start`, phase 전환·pause/resume에서 `update`, 종료 시 `end`.
    private let liveActivity: LiveActivityHooks?
    /// 현재 시각 provider — 테스트에서 결정적 clock을 주입하려고 추상화. 기본은 `Date.now`.
    /// 모든 시각 계산(deadline·remaining·pauseTime)이 이 하나만 읽는다.
    private let now: () -> Date

    /// 세션과 라이브 액티비티를 연결하는 묶음. `FocusViewModel.start()`가 만들어 주입.
    /// session 식별자·표시 타이틀·색·세 use case를 함께 들고 다닌다 — init 시그니처가 여러
    /// 인자로 부풀지 않게.
    struct LiveActivityHooks: Sendable {
        let sessionID: UUID
        let sessionTitle: String
        /// 세션 색 hex. widget이 외곽 stroke·아이콘 등에 사용. nil이면 시스템 accent로 폴백.
        let colorHex: String?
        let start: StartFocusLiveActivityUseCase
        let update: UpdateFocusLiveActivityUseCase
        let end: EndFocusLiveActivityUseCase
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

    init(
        settings: FocusSettings,
        scheduler: any FocusNotificationScheduling,
        liveActivity: LiveActivityHooks? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.liveActivity = liveActivity
        self.now = now
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
        // 세션 시작 = LA start. Task 안에선 hook 값만 capture — self capture 회피.
        if let hooks = liveActivity {
            Task {
                try? await hooks.start(
                    sessionID: hooks.sessionID,
                    sessionTitle: hooks.sessionTitle,
                    colorHex: hooks.colorHex,
                    phase: .focus,
                    phaseStartDate: phaseStart,
                    phaseEndDate: phaseEnd
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

    /// 일시정지 — `tick`이 멈추고, 단계 종료 pending 알림은 취소된다. 현재 `remaining`을
    /// 벽시계 기준으로 한 번 박아 고정한다. 라이브 액티비티는 `pauseTime`을 set하고 같은
    /// `phaseEndDate`를 받으므로, LA 정지 표시(`phaseEndDate - pauseTime`)가 앱 `remaining`과
    /// 정확히 일치한다 — 시스템 타이머 위임이라 앱이 매초 update할 필요 없음.
    func pause() {
        guard !isPaused, !isComplete else { return }
        remaining = max(0, phaseEndDate.timeIntervalSince(now()))
        isPaused = true
        scheduler.cancelAll()
        scheduleLiveActivityUpdate(pauseTime: now())
    }

    /// 재개 — 고정해 둔 `remaining`으로 deadline을 다시 잡는다. `phaseEndDate = now + remaining`,
    /// `phaseStartDate = phaseEndDate - phaseDuration`으로 interval 길이를 phaseDuration 그대로
    /// 유지하고 `pauseTime` 해제. 앱·LA가 동일한 새 deadline을 공유한다.
    func resume() {
        guard isPaused, !isComplete else { return }
        isPaused = false
        phaseEndDate = now().addingTimeInterval(remaining)
        phaseStartDate = phaseEndDate.addingTimeInterval(-phaseDuration)
        scheduler.schedulePhaseEnd(
            after: remaining,
            title: Self.title(for: phase),
            body: Self.body(for: phase)
        )
        scheduleLiveActivityUpdate(pauseTime: nil)
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
