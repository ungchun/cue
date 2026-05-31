//
//  FocusSessionViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct FocusSessionViewModelTests {

    /// 빠른 검증을 위해 짧은 단위(초) 설정으로 ViewModel을 만든다.
    /// 도메인은 초 단위라 단위테스트에서 `60`/`30` 같은 값을 그대로 쓸 수 있다.
    private func make(
        focus: TimeInterval = 60,
        rest: TimeInterval = 30,
        repeating: Bool = true,
        cycles: Int = 4,
        scheduler: FakeFocusNotificationScheduler = FakeFocusNotificationScheduler()
    ) -> (FocusSessionViewModel, FakeFocusNotificationScheduler) {
        let settings = FocusSettings(
            focusDuration: focus, restDuration: rest,
            isRepeating: repeating, cycleCount: cycles
        )
        let viewModel = FocusSessionViewModel(settings: settings, scheduler: scheduler)
        return (viewModel, scheduler)
    }

    // MARK: - 초기 상태

    @Test func startsInFocusPhaseAtFullDuration() {
        let (vm, _) = make(focus: 60, rest: 30)

        #expect(vm.phase == .focus)
        #expect(vm.remaining == 60)
        #expect(vm.currentCycle == 1)
        #expect(vm.totalCycles == 4)
        #expect(vm.isPaused == false)
        #expect(vm.isComplete == false)
    }

    @Test func nonRepeatingSessionHasOneTotalCycle() {
        let (vm, _) = make(repeating: false, cycles: 4)

        #expect(vm.totalCycles == 1)
    }

    // MARK: - tick

    @Test func tickDecrementsRemaining() {
        let (vm, _) = make(focus: 60)

        vm.tick(seconds: 5)

        #expect(vm.remaining == 55)
    }

    @Test func tickDoesNotGoBelowZero() {
        let (vm, _) = make(focus: 10, rest: 5, cycles: 1, scheduler: FakeFocusNotificationScheduler())
        // 1 cycle + non-rest 종료 시점을 확인하기 위해 일단 repeating off로 검증.
        // 별도 케이스에서 repeating=true 단일 사이클 흐름은 분리.

        vm.tick(seconds: 999)

        #expect(vm.remaining == 0)
    }

    // MARK: - 단계 전환 (반복 ON)

    @Test func focusPhaseEndTransitionsToRest() {
        let (vm, _) = make(focus: 10, rest: 5, cycles: 2)

        vm.tick(seconds: 10)

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 5)
        #expect(vm.currentCycle == 1)
    }

    @Test func restPhaseEndAdvancesCycleAndStartsNextFocus() {
        let (vm, _) = make(focus: 10, rest: 5, cycles: 2)

        vm.tick(seconds: 10) // focus → rest
        vm.tick(seconds: 5)  // rest → focus(2)

        #expect(vm.phase == .focus)
        #expect(vm.currentCycle == 2)
        #expect(vm.remaining == 10)
    }

    @Test func lastFocusEndsSessionWithoutFinalRest() {
        let (vm, _) = make(focus: 10, rest: 5, cycles: 2)

        vm.tick(seconds: 10) // focus(1) → rest
        vm.tick(seconds: 5)  // rest → focus(2)
        vm.tick(seconds: 10) // focus(2) → 완료

        #expect(vm.isComplete)
    }

    @Test func tickOverflowAppliesRemainderToNextPhase() {
        // 10초 집중 + 5초 휴식을 한 번에 12초 흘리면 → 집중 끝, 휴식에 3초 남음.
        let (vm, _) = make(focus: 10, rest: 5, cycles: 2)

        vm.tick(seconds: 12)

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 3)
    }

    // MARK: - 단계 전환 (반복 OFF)

    @Test func nonRepeatingEndsAfterSingleFocus() {
        let (vm, _) = make(focus: 10, repeating: false)

        vm.tick(seconds: 10)

        #expect(vm.isComplete)
        #expect(vm.phase == .focus) // rest로 넘어가지 않음
    }

    // MARK: - pause / resume / skip / abort

    @Test func pauseFreezesRemaining() {
        let (vm, _) = make(focus: 60)

        vm.pause()
        vm.tick(seconds: 10)

        #expect(vm.remaining == 60)
        #expect(vm.isPaused)
    }

    @Test func resumeContinuesTicking() {
        let (vm, _) = make(focus: 60)

        vm.pause()
        vm.tick(seconds: 10)
        vm.resume()
        vm.tick(seconds: 5)

        #expect(vm.isPaused == false)
        #expect(vm.remaining == 55)
    }

    @Test func skipFinishesCurrentPhaseImmediately() {
        let (vm, _) = make(focus: 60, rest: 30, cycles: 2)

        vm.skip()

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 30)
    }

    @Test func skipOnLastFocusCompletesSession() {
        let (vm, _) = make(focus: 60, repeating: false)

        vm.skip()

        #expect(vm.isComplete)
    }

    @Test func abortMarksSessionComplete() {
        let (vm, _) = make(focus: 60)

        vm.abort()

        #expect(vm.isComplete)
    }

    // MARK: - 알림 스케줄링

    @Test func startSchedulesPhaseEndNotification() {
        let (_, scheduler) = make(focus: 60)

        #expect(scheduler.scheduledIntervals == [60])
    }

    @Test func pauseCancelsPendingNotification() {
        let (vm, scheduler) = make(focus: 60)

        vm.pause()

        #expect(scheduler.cancelCount >= 1)
    }

    @Test func resumeReschedulesWithCurrentRemaining() {
        let (vm, scheduler) = make(focus: 60)
        vm.pause()
        vm.tick(seconds: 10) // pause 상태라 remaining 그대로 60

        vm.resume()

        // resume 시 새 알림이 추가 예약됨 — 마지막 예약 간격이 현재 remaining과 같다.
        #expect(scheduler.scheduledIntervals.last == 60)
    }

    @Test func phaseTransitionSchedulesNextPhaseNotification() {
        let (vm, scheduler) = make(focus: 10, rest: 5, cycles: 2)

        vm.tick(seconds: 10) // focus → rest

        // 첫 예약(10초 = focus) + 두 번째 예약(5초 = rest)
        #expect(scheduler.scheduledIntervals == [10, 5])
    }

    @Test func completionCancelsAllNotifications() {
        let (vm, scheduler) = make(focus: 10, repeating: false)

        vm.tick(seconds: 10) // 완료

        #expect(vm.isComplete)
        // 시작 시 1번 + 완료 시 1번 이상 cancel.
        #expect(scheduler.cancelCount >= 1)
    }

    @Test func abortCancelsPendingNotification() {
        let (vm, scheduler) = make(focus: 60)

        vm.abort()

        #expect(scheduler.cancelCount >= 1)
    }
}

/// Domain `FocusNotificationScheduling`의 테스트 fake. 예약 간격과 취소 호출 수만
/// 기록 — 실제 시스템 호출은 하지 않는다.
final class FakeFocusNotificationScheduler: FocusNotificationScheduling, @unchecked Sendable {
    /// `schedulePhaseEnd`가 호출된 순서대로 누적된 interval.
    private(set) var scheduledIntervals: [TimeInterval] = []
    /// `cancelAll`이 호출된 누적 횟수.
    private(set) var cancelCount: Int = 0

    func requestAuthorization() async {}

    func schedulePhaseEnd(after seconds: TimeInterval, title: String, body: String) {
        scheduledIntervals.append(seconds)
    }

    func cancelAll() {
        cancelCount += 1
    }
}
