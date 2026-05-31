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

    /// 현재 단계.
    private(set) var phase: FocusPhase = .focus
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

    init(settings: FocusSettings, scheduler: any FocusNotificationScheduling) {
        self.settings = settings
        self.scheduler = scheduler
        self.remaining = settings.focusDuration
        self.totalCycles = settings.totalCycles
        scheduler.schedulePhaseEnd(
            after: settings.focusDuration,
            title: Self.title(for: .focus),
            body: Self.body(for: .focus)
        )
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
    func pause() {
        guard !isPaused, !isComplete else { return }
        isPaused = true
        scheduler.cancelAll()
    }

    /// 재개 — 현재 남은 시간으로 단계 종료 알림을 다시 예약한다.
    func resume() {
        guard isPaused, !isComplete else { return }
        isPaused = false
        scheduler.schedulePhaseEnd(
            after: remaining,
            title: Self.title(for: phase),
            body: Self.body(for: phase)
        )
    }

    /// 현재 단계를 즉시 끝낸 것으로 처리하고 다음 단계로 넘긴다(혹은 세션 종료).
    func skip() {
        guard !isComplete else { return }
        remaining = 0
        advancePhase()
    }

    /// 세션을 강제 종료 — `isComplete = true`로 두고 pending 알림을 비운다.
    /// 뷰는 `isComplete` 관찰로 시트를 닫는다.
    func abort() {
        guard !isComplete else { return }
        isComplete = true
        scheduler.cancelAll()
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
                return
            }
            phase = .rest
            remaining = settings.restDuration
            scheduler.schedulePhaseEnd(
                after: remaining,
                title: Self.title(for: .rest),
                body: Self.body(for: .rest)
            )
        case .rest:
            // 휴식이 끝나면 다음 사이클의 집중으로.
            currentCycle += 1
            phase = .focus
            remaining = settings.focusDuration
            scheduler.schedulePhaseEnd(
                after: remaining,
                title: Self.title(for: .focus),
                body: Self.body(for: .focus)
            )
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
