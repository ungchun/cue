//
//  FocusSessionViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 진행 중인 집중 세션의 상태머신.
///
/// 단계(`focus`/`rest`) · 남은 시간(`remaining`) · 현재 사이클을 들고 있고, `tick(seconds:)`이
/// 호출될 때마다 시간을 갉아 단계 전환·세션 완료를 처리한다. 뷰는 `Timer.publish`로
/// 1초마다 `tick(seconds: 1)`을 부른다.
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
    /// 현재 단계의 남은 시간(초). `tick`이 갉고, pause면 멈춘다.
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
        liveActivity: LiveActivityHooks? = nil
    ) {
        self.settings = settings
        self.scheduler = scheduler
        self.liveActivity = liveActivity
        let phaseStart = Date.now
        self.phaseStartDate = phaseStart
        self.remaining = settings.focusDuration
        self.totalCycles = settings.totalCycles
        scheduler.schedulePhaseEnd(
            after: settings.focusDuration,
            title: Self.title(for: .focus),
            body: Self.body(for: .focus)
        )
        // 세션 시작 = LA start. Task 안에선 hook 값만 capture — self capture 회피.
        if let hooks = liveActivity {
            let phaseEnd = phaseStart.addingTimeInterval(settings.focusDuration)
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

    /// 단계 종료 알림 없이 진행 시간을 흘려보낸다. 1초든 30초든 받는 양만큼 갉고,
    /// 남는 분량이 있으면 다음 단계로 캐스케이드한다(예: 12초 흘렸는데 8초 남았던 단계 —
    /// 남은 4초는 다음 단계의 시작에서 다시 차감).
    func tick(seconds: TimeInterval) {
        guard !isPaused, !isComplete else { return }
        var remainder = seconds
        while remainder > 0 && !isComplete {
            if remainder < remaining {
                remaining -= remainder
                remainder = 0
            } else {
                // 현재 단계 종료. 남은 양은 다음 단계로 이월.
                remainder -= remaining
                remaining = 0
                advancePhase()
            }
        }
    }

    // MARK: - 사용자 액션

    /// 일시정지 — `tick`이 멈추고, 단계 종료 pending 알림은 취소된다.
    /// 라이브 액티비티는 `pauseTime`을 set하여 카운트다운 표시를 멈춘다 — 시스템 타이머
    /// 위임이라 앱이 매초 update할 필요 없음.
    func pause() {
        guard !isPaused, !isComplete else { return }
        isPaused = true
        scheduler.cancelAll()
        scheduleLiveActivityUpdate(pauseTime: .now)
    }

    /// 재개 — 현재 남은 시간으로 단계 종료 알림을 다시 예약한다.
    /// 라이브 액티비티는 `phaseStartDate = now - elapsed`, `phaseEndDate = now + remaining`으로
    /// 다시 잡아 interval 길이를 phaseDuration 그대로 유지하고 `pauseTime` 해제.
    func resume() {
        guard isPaused, !isComplete else { return }
        isPaused = false
        let elapsed = phaseDuration - remaining
        phaseStartDate = Date.now.addingTimeInterval(-elapsed)
        scheduler.schedulePhaseEnd(
            after: remaining,
            title: Self.title(for: phase),
            body: Self.body(for: phase)
        )
        scheduleLiveActivityUpdate(pauseTime: nil)
    }

    /// 현재 단계를 즉시 끝낸 것으로 처리하고 다음 단계로 넘긴다(혹은 세션 종료).
    func skip() {
        guard !isComplete else { return }
        remaining = 0
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
        switch phase {
        case .focus:
            // 반복 OFF거나 마지막 사이클의 집중이 끝나면 세션 종료(휴식 없음).
            if !settings.isRepeating || currentCycle >= totalCycles {
                isComplete = true
                scheduleLiveActivityEnd()
                return
            }
            phase = .rest
            phaseStartDate = .now
            remaining = settings.restDuration
            scheduler.schedulePhaseEnd(
                after: remaining,
                title: Self.title(for: .rest),
                body: Self.body(for: .rest)
            )
            scheduleLiveActivityUpdate(pauseTime: nil)
        case .rest:
            // 휴식이 끝나면 다음 사이클의 집중으로.
            currentCycle += 1
            phase = .focus
            phaseStartDate = .now
            remaining = settings.focusDuration
            scheduler.schedulePhaseEnd(
                after: remaining,
                title: Self.title(for: .focus),
                body: Self.body(for: .focus)
            )
            scheduleLiveActivityUpdate(pauseTime: nil)
        }
    }

    // MARK: - 라이브 액티비티 호출 helpers

    /// 현재 phase·remaining·pauseTime을 스냅샷 떠 LA `update`를 비동기 dispatch.
    /// hooks가 nil이면 no-op. 매초 호출 금지 — phase 전환/pause/resume에서만 부른다.
    private func scheduleLiveActivityUpdate(pauseTime: Date?) {
        guard let hooks = liveActivity else { return }
        let phaseSnapshot = liveFocusPhase
        let startSnapshot = phaseStartDate
        let endSnapshot = Date.now.addingTimeInterval(remaining)
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
