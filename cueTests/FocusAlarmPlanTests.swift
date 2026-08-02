//
//  FocusAlarmPlanTests.swift
//  cueTests
//
//  잠금화면 "다음 단계" 카드의 예약 자격 — 끝난 세션의 버튼이 살아 있으면 안 된다.
//

import Foundation
import Testing
@testable import cue

/// 세션 진행 상태를 plan이 들고, 잠금화면 체이닝 인텐트의 예약 자격을 판정하는 규칙.
///
/// 증상(2026-08-02 보고): 켠 적 없는 뽀모도로가 한 번씩 진행 중이었다. 초가 정상적으로 줄고
/// 있었으므로 **살아있는 AlarmKit 알람이 새로 예약된 것** — 앱이 포그라운드가 아니었으니
/// 경로는 `FocusAlarmAdvanceIntent`(잠금화면 알림의 "휴식 시작" secondary 버튼) 하나뿐이다.
///
/// 원인 — 그 인텐트에 자격 검사가 없었다. 유일한 관문인 `FocusAlarmPlan`은 "설정 스냅샷"일
/// 뿐 세션 식별자도 진행 단계도 없고, 인앱 종료(`tearDownSession`) 말고는 지워지지 않았다.
/// 잠금화면 종료(`FocusAlarmStopIntent`)·알림 방치·강제종료는 전부 plan을 남긴다. 그래서
/// **며칠 전 세션이 남긴 카드의 버튼이 그대로 유효**했고, 한 번 스치면 25분짜리 단계가 예약됐다.
///
/// 규칙 — plan이 "다음에 예약이 허용되는 단계"를 들고, 카드가 요구하는 단계와 일치할 때만
/// 통과시킨다. 예약에 성공하면 기대값이 한 칸 전진하므로 유효한 카드도 **한 번만** 먹는다.
///
/// 인앱 경로(Start·Skip)에는 이 판정을 걸지 않는다 — 잠금화면에서 한 단계 넘어간 뒤 앱이 아직
/// 채택하지 못한 상태의 Skip이 조용히 무시되기 때문. 앱이 살아 있고 사용자가 화면을 보며
/// 누르는 상황이라 오탭 위험의 성격이 다르고, 그쪽은 VM이 권위다.
struct FocusAlarmPlanTests {

    private func plan(nextAllowed: FocusAlarmPlan.Step?) -> FocusAlarmPlan {
        FocusAlarmPlan(
            focusDuration: 25 * 60,
            restDuration: 5 * 60,
            totalCycles: 4,
            sessionTitle: "Cue",
            colorHex: nil,
            soundEnabled: false,
            nextAllowed: nextAllowed
        )
    }

    // MARK: - 재현: 끝난 세션의 카드는 먹으면 안 된다

    /// **재현 핵심.** 이미 다음 단계가 예약돼 기대값이 전진한 뒤, 지난 카드가 옛 단계를
    /// 요구하면 거부해야 한다. 지금 코드는 plan 존재 여부만 보므로 그대로 예약해버린다.
    @Test func rejectsStepFromStaleCard() {
        let current = plan(nextAllowed: .init(phase: .focus, cycle: 2))

        #expect(current.accepts(phase: .rest, cycle: 1) == false)
    }

    /// 같은 사이클이라도 단계가 다르면 거부.
    @Test func rejectsMismatchedPhase() {
        let current = plan(nextAllowed: .init(phase: .rest, cycle: 1))

        #expect(current.accepts(phase: .focus, cycle: 1) == false)
    }

    /// 같은 단계라도 사이클이 다르면 거부 — 이전 사이클의 카드가 남아 있는 경우.
    @Test func rejectsMismatchedCycle() {
        let current = plan(nextAllowed: .init(phase: .focus, cycle: 3))

        #expect(current.accepts(phase: .focus, cycle: 2) == false)
    }

    /// 이어질 단계가 없으면(마지막 집중 완료) 무엇도 통과시키지 않는다.
    @Test func rejectsEverythingWhenNoNextStepRemains() {
        let finished = plan(nextAllowed: nil)

        #expect(finished.accepts(phase: .focus, cycle: 1) == false)
        #expect(finished.accepts(phase: .rest, cycle: 1) == false)
    }

    // MARK: - 정상 체이닝은 그대로 동작해야 한다

    /// 경계에서 뜬 진짜 카드는 통과 — 이걸 막으면 잠금화면 체이닝 기능 자체가 죽는다.
    @Test func acceptsExpectedNextStep() {
        let current = plan(nextAllowed: .init(phase: .rest, cycle: 1))

        #expect(current.accepts(phase: .rest, cycle: 1))
    }

    /// 예약이 끝나면 기대값이 다음 단계로 전진한다.
    @Test func expectingAdvancesTheAllowedStep() {
        let current = plan(nextAllowed: .init(phase: .rest, cycle: 1))

        let advanced = current.expecting(.init(phase: .focus, cycle: 2))

        #expect(advanced.nextAllowed == FocusAlarmPlan.Step(phase: .focus, cycle: 2))
        #expect(advanced.accepts(phase: .focus, cycle: 2))
    }

    /// 전진해도 설정 스냅샷은 그대로 — 길이·타이틀·색·소리는 세션 내내 고정이다.
    @Test func expectingKeepsSettingsSnapshot() {
        let current = plan(nextAllowed: .init(phase: .rest, cycle: 1))

        let advanced = current.expecting(.init(phase: .focus, cycle: 2))

        #expect(advanced.focusDuration == current.focusDuration)
        #expect(advanced.restDuration == current.restDuration)
        #expect(advanced.totalCycles == current.totalCycles)
        #expect(advanced.sessionTitle == current.sessionTitle)
        #expect(advanced.soundEnabled == current.soundEnabled)
    }

    /// **같은 카드 두 번 탭** — 첫 탭이 기대값을 전진시키므로 두 번째는 거부된다.
    /// (지금은 두 번 다 예약돼, 방금 시작한 단계가 리셋된다.)
    @Test func sameCardCannotBeUsedTwice() {
        let current = plan(nextAllowed: .init(phase: .rest, cycle: 1))

        #expect(current.accepts(phase: .rest, cycle: 1))
        let afterFirstTap = current.expecting(.init(phase: .focus, cycle: 2))

        #expect(afterFirstTap.accepts(phase: .rest, cycle: 1) == false)
    }

    /// 마지막 단계를 예약하면 기대값이 사라져 이후 어떤 카드도 안 먹는다.
    @Test func expectingNilClosesTheSession() {
        let current = plan(nextAllowed: .init(phase: .focus, cycle: 4))

        let closed = current.expecting(nil)

        #expect(closed.nextAllowed == nil)
        #expect(closed.accepts(phase: .focus, cycle: 4) == false)
    }
}
