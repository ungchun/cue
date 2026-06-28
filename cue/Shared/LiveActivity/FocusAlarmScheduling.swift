//
//  FocusAlarmScheduling.swift
//  cue / Shared
//

import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI

// MARK: - 타깃 멤버십
//
// 메인 앱(컨트롤러)과 위젯 익스텐션(체이닝 인텐트)이 같은 config를 만든다 — pbxproj exception 필요.

/// AlarmKit 알람 한 단계를 구성·예약하는 공용 헬퍼.
///
/// 뽀모도로는 단계별 알람을 **하나씩** 예약하고 경계에서 다음 단계를 잇는다(`maximumLimitReached`
/// 회피 + force-quit 생존). 세션 설정은 `FocusAlarmPlan`(App Group)에서 읽으므로, 메인 앱이든
/// 위젯 인텐트든 동일한 길이·타이틀·색으로 다음 단계를 예약할 수 있다.
///
/// 알림(경계 도달) 화면의 secondary 버튼("휴식 시작" 등)에 `FocusAlarmAdvanceIntent`를 달아 잠금화면
/// 에서 탭으로 다음 단계가 예약되게 한다(`secondaryButtonBehavior: .custom`). 포그라운드에선 앱이
/// `alarmUpdates`를 보고 자동 전환한다 — 둘 다 같은 `schedule`로 수렴.
enum FocusAlarmScheduling {

    /// 한 단계가 끝난 뒤 이어질 단계. nil이면 세션 종료(마지막 집중 후 휴식 없음).
    static func nextStep(
        after phase: FocusAlarmMetadata.Phase,
        cycle: Int,
        totalCycles: Int
    ) -> (phase: FocusAlarmMetadata.Phase, cycle: Int)? {
        switch phase {
        case .focus: return cycle >= totalCycles ? nil : (.rest, cycle)
        case .rest: return (.focus, cycle + 1)
        }
    }

    static func label(_ phase: FocusAlarmMetadata.Phase) -> String {
        phase == .focus ? "집중" : "휴식"
    }

    /// 현재 플랜으로 한 단계 알람을 예약하고 alarmID를 반환. 플랜이 없으면 nil.
    ///
    /// **예약 직전 기존 알람을 전부 취소**한다 — 단계 전환 시(포그라운드 자동전환이든, 잠금화면
    /// "다음 단계" 탭이든) 이전 알람이 남아 Live Activity가 여러 개 쌓이는 걸 막는다. 이 앱은
    /// 한 번에 한 개의 집중 알람만 두는 정책이라 전부 취소해도 안전하다.
    @discardableResult
    static func schedule(phase: FocusAlarmMetadata.Phase, cycle: Int) async -> UUID? {
        guard let plan = FocusAlarmPlan.load() else { return nil }
        cancelAll()
        let id = UUID()
        let config = makeConfig(id: id, phase: phase, cycle: cycle, plan: plan)
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: config)
            return id
        } catch {
            return nil
        }
    }

    /// 이 앱이 예약한 알람을 전부 취소 — 단계 전환·종료에서 LA 누적을 막는다.
    static func cancelAll() {
        guard let existing = try? AlarmManager.shared.alarms else { return }
        for alarm in existing { try? AlarmManager.shared.cancel(id: alarm.id) }
    }

    /// 단계 → AlarmConfiguration. 카운트다운/일시정지/알림 presentation을 구성한다.
    static func makeConfig(
        id: UUID,
        phase: FocusAlarmMetadata.Phase,
        cycle: Int,
        plan: FocusAlarmPlan
    ) -> AlarmManager.AlarmConfiguration<FocusAlarmMetadata> {
        let next = nextStep(after: phase, cycle: cycle, totalCycles: plan.totalCycles)

        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: label(phase)),
            pauseButton: AlarmButton(text: "일시정지", textColor: .white, systemImageName: "pause.fill")
        )
        let paused = AlarmPresentation.Paused(
            title: LocalizedStringResource(stringLiteral: "\(label(phase)) 일시정지"),
            resumeButton: AlarmButton(text: "재개", textColor: .white, systemImageName: "play.fill")
        )

        // 다음 단계가 있으면 알림에 "다음 단계 시작" secondary 버튼 + 체이닝 인텐트.
        let secondaryButton: AlarmButton?
        let secondaryIntent: (any LiveActivityIntent)?
        if let next {
            secondaryButton = AlarmButton(
                text: LocalizedStringResource(stringLiteral: "\(label(next.phase)) 시작"),
                textColor: .white,
                systemImageName: "arrow.right"
            )
            secondaryIntent = FocusAlarmAdvanceIntent(nextPhaseRaw: next.phase.rawValue, nextCycle: next.cycle)
        } else {
            secondaryButton = nil
            secondaryIntent = nil
        }
        // 26.1 init(stopButton 없음) — 시스템이 종료(배너에선 탭 X, 전체화면에선 slide-to-stop)를
        // 그린다. deprecated stopButton init은 26.1에서 알림 표시를 깨뜨려 되돌림.
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "\(label(phase)) 완료"),
            secondaryButton: secondaryButton,
            secondaryButtonBehavior: secondaryButton == nil ? nil : .custom
        )

        let presentation = AlarmPresentation(alert: alert, countdown: countdown, paused: paused)
        let metadata = FocusAlarmMetadata(
            phase: phase,
            cycle: cycle,
            totalCycles: plan.totalCycles,
            sessionTitle: plan.sessionTitle,
            colorHex: plan.colorHex
        )
        let tint = plan.colorHex.flatMap { Color(hex: $0) } ?? .indigo
        let attributes = AlarmAttributes(presentation: presentation, metadata: metadata, tintColor: tint)

        // 소리 켜짐이면 시스템 기본 알람음, 꺼짐이면 번들의 무음 wav(silent.wav)를 커스텀 사운드로
        // 지정해 사실상 음소거한다(`sound`는 non-optional이고 `.none`이 없음). 정책은 세션 시작 시
        // `FocusAlarmPlan.soundEnabled`로 굳혀, 메인 앱·위젯 인텐트가 동일하게 예약한다.
        return AlarmManager.AlarmConfiguration.timer(
            duration: plan.duration(for: phase),
            attributes: attributes,
            stopIntent: FocusAlarmStopIntent(alarmID: id.uuidString),
            secondaryIntent: secondaryIntent,
            sound: plan.soundEnabled ? .default : .named("silent.wav")
        )
    }
}
