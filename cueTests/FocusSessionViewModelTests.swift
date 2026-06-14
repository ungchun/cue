//
//  FocusSessionViewModelTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct FocusSessionViewModelTests {

    /// 결정적 테스트용 가변 clock. `advance`로 벽시계를 임의로 흘린다.
    /// 도메인이 주입된 `now: () -> Date`로만 시각을 읽으므로 테스트가 시간을 완전 통제한다.
    final class TestClock {
        var current: Date
        init(_ start: Date = Date(timeIntervalSinceReferenceDate: 0)) { self.current = start }
        func advance(_ seconds: TimeInterval) { current += seconds }
    }

    /// 빠른 검증을 위해 짧은 단위(초) 설정으로 ViewModel을 만든다.
    /// 도메인은 초 단위라 단위테스트에서 `60`/`30` 같은 값을 그대로 쓸 수 있다.
    private func make(
        focus: TimeInterval = 60,
        rest: TimeInterval = 30,
        repeating: Bool = true,
        cycles: Int = 4,
        scheduler: FakeFocusNotificationScheduler = FakeFocusNotificationScheduler(),
        clock: TestClock = TestClock()
    ) -> (FocusSessionViewModel, FakeFocusNotificationScheduler, TestClock) {
        let settings = FocusSettings(
            focusDuration: focus, restDuration: rest,
            isRepeating: repeating, cycleCount: cycles
        )
        let viewModel = FocusSessionViewModel(
            settings: settings,
            scheduler: scheduler,
            now: { clock.current }
        )
        return (viewModel, scheduler, clock)
    }

    // MARK: - 초기 상태

    @Test func startsInFocusPhaseAtFullDuration() {
        let (vm, _, _) = make(focus: 60, rest: 30)

        #expect(vm.phase == .focus)
        #expect(vm.remaining == 60)
        #expect(vm.currentCycle == 1)
        #expect(vm.totalCycles == 4)
        #expect(vm.isPaused == false)
        #expect(vm.isComplete == false)
    }

    @Test func nonRepeatingSessionHasOneTotalCycle() {
        let (vm, _, _) = make(repeating: false, cycles: 4)

        #expect(vm.totalCycles == 1)
    }

    // MARK: - tick (벽시계 파생)

    @Test func tickRecomputesRemainingFromClock() {
        let (vm, _, clock) = make(focus: 60)

        clock.advance(5)
        vm.tick()

        #expect(vm.remaining == 55)
    }

    /// remaining은 정수 tick 감산이 아니라 벽시계 파생이라 소수 초도 정확 — counter drift 없음.
    @Test func remainingTracksWallClockFractionally() {
        let (vm, _, clock) = make(focus: 60)

        clock.advance(3.5)
        vm.tick()

        #expect(vm.remaining == 56.5)
    }

    @Test func tickDoesNotGoBelowZero() {
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 1)

        clock.advance(999)
        vm.tick()

        #expect(vm.remaining == 0)
    }

    // MARK: - 앱 / 라이브 액티비티 싱크 (deadline = single source of truth)

    /// `phaseEndDate`는 시간이 흘러도 불변인 deadline이고, `remaining = phaseEndDate - now`가
    /// 성립한다. LA에 같은 `phaseEndDate`를 넘기므로 앱과 LA가 항상 같은 값을 읽는다.
    @Test func phaseEndDateIsStableSourceOfTruth() {
        let (vm, _, clock) = make(focus: 60)
        let deadline = vm.phaseEndDate

        clock.advance(10)
        vm.tick()

        #expect(vm.phaseEndDate == deadline)
        #expect(vm.remaining == 50)
        #expect(vm.phaseEndDate.timeIntervalSince(clock.current) == vm.remaining)
    }

    /// 백그라운드로 한 단계 전체가 지나도, 포그라운드 복귀의 단일 `tick()`이 정확히 착지한다
    /// (counter 추격 tick 없음) — '초가 확확 줄어드는' 점프의 근본 제거.
    @Test func singleTickCatchesUpAcrossElapsedPhases() {
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(12) // focus(10) 끝 + rest 2초 경과
        vm.tick()         // 복귀 시 단 한 번

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 3)
    }

    // MARK: - 단계 전환 (반복 ON)

    @Test func focusPhaseEndTransitionsToRest() {
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(10)
        vm.tick()

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 5)
        #expect(vm.currentCycle == 1)
    }

    @Test func restPhaseEndAdvancesCycleAndStartsNextFocus() {
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(10); vm.tick() // focus → rest
        clock.advance(5);  vm.tick() // rest → focus(2)

        #expect(vm.phase == .focus)
        #expect(vm.currentCycle == 2)
        #expect(vm.remaining == 10)
    }

    @Test func lastFocusEndsSessionWithoutFinalRest() {
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(10); vm.tick() // focus(1) → rest
        clock.advance(5);  vm.tick() // rest → focus(2)
        clock.advance(10); vm.tick() // focus(2) → 완료

        #expect(vm.isComplete)
    }

    @Test func tickOverflowAppliesRemainderToNextPhase() {
        // 10초 집중 + 5초 휴식 중 12초가 흐르면 → 집중 끝, 휴식에 3초 남음.
        let (vm, _, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(12)
        vm.tick()

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 3)
    }

    // MARK: - 단계 전환 (반복 OFF)

    @Test func nonRepeatingEndsAfterSingleFocus() {
        let (vm, _, clock) = make(focus: 10, repeating: false)

        clock.advance(10)
        vm.tick()

        #expect(vm.isComplete)
        #expect(vm.phase == .focus) // rest로 넘어가지 않음
    }

    // MARK: - pause / resume / skip / abort

    @Test func pauseFreezesRemaining() {
        let (vm, _, clock) = make(focus: 60)

        vm.pause()
        clock.advance(10)
        vm.tick()

        #expect(vm.remaining == 60)
        #expect(vm.isPaused)
    }

    @Test func resumeContinuesTicking() {
        let (vm, _, clock) = make(focus: 60)

        vm.pause()
        clock.advance(10) // pause 중 — 무시
        vm.tick()
        vm.resume()
        clock.advance(5)
        vm.tick()

        #expect(vm.isPaused == false)
        #expect(vm.remaining == 55)
    }

    /// pause(at:)는 drain 시점이 아니라 **누른 시각** 기준으로 freeze — LA에서 누른 뒤 앱을
    /// 늦게 열어도 그 사이 시간이 새지 않는다(사용자 보고 버그: 40초에 멈췄는데 35초로 재개).
    @Test func pauseAtFreezesAsOfPressTime() {
        let (vm, _, clock) = make(focus: 60)

        clock.advance(10) // 앱이 늦게 drain되는 시점
        vm.pause(at: Date(timeIntervalSinceReferenceDate: 5)) // 실제로 누른 시각 = 5초

        #expect(vm.remaining == 55) // 50(drain 기준)이 아니라 55(누른 시각 기준)
        #expect(vm.isPaused)
    }

    /// 잔재 액션의 과거 시각이 들어와도 잔여는 단계 길이를 못 넘게 클램프(33분 부풀림 버그 방어).
    @Test func pauseAtClampsRemainingToPhaseDuration() {
        let (vm, _, _) = make(focus: 60) // phaseEndDate = T0+60

        vm.pause(at: Date(timeIntervalSinceReferenceDate: -30)) // 과거 시각

        #expect(vm.remaining == 60) // 90이 아니라 60으로 클램프
    }

    /// resume(at:)는 누른 시각 기준으로 deadline을 재구성 — 누른 뒤 흐른 시간은 정상 카운트다운.
    @Test func resumeAtRebuildsDeadlineFromPressTime() {
        let (vm, _, clock) = make(focus: 60)

        vm.pause()        // remaining 60 (clock 0)
        clock.advance(20) // drain 시점 = 20
        vm.resume(at: Date(timeIntervalSinceReferenceDate: 15)) // 재개 누른 시각 = 15
        vm.tick()         // now = 20 → 재개 후 5초 경과

        #expect(vm.remaining == 55) // 60(now 기준)이 아니라 55(누른 시각 15 기준)
        #expect(vm.isPaused == false)
    }

    @Test func skipFinishesCurrentPhaseImmediately() {
        let (vm, _, _) = make(focus: 60, rest: 30, cycles: 2)

        vm.skip()

        #expect(vm.phase == .rest)
        #expect(vm.remaining == 30)
    }

    @Test func skipOnLastFocusCompletesSession() {
        let (vm, _, _) = make(focus: 60, repeating: false)

        vm.skip()

        #expect(vm.isComplete)
    }

    @Test func abortMarksSessionComplete() {
        let (vm, _, _) = make(focus: 60)

        vm.abort()

        #expect(vm.isComplete)
    }

    // MARK: - 알림 스케줄링

    @Test func startSchedulesPhaseEndNotification() {
        let (_, scheduler, _) = make(focus: 60)

        #expect(scheduler.scheduledIntervals == [60])
    }

    @Test func pauseCancelsPendingNotification() {
        let (vm, scheduler, _) = make(focus: 60)

        vm.pause()

        #expect(scheduler.cancelCount >= 1)
    }

    @Test func resumeReschedulesWithCurrentRemaining() {
        let (vm, scheduler, clock) = make(focus: 60)
        vm.pause()
        clock.advance(10) // pause 상태라 remaining 그대로 60
        vm.tick()

        vm.resume()

        // resume 시 새 알림이 추가 예약됨 — 마지막 예약 간격이 현재 remaining과 같다.
        #expect(scheduler.scheduledIntervals.last == 60)
    }

    @Test func phaseTransitionSchedulesNextPhaseNotification() {
        let (vm, scheduler, clock) = make(focus: 10, rest: 5, cycles: 2)

        clock.advance(10)
        vm.tick() // focus → rest

        // 첫 예약(10초 = focus) + 두 번째 예약(5초 = rest)
        #expect(scheduler.scheduledIntervals == [10, 5])
    }

    @Test func completionCancelsAllNotifications() {
        let (vm, scheduler, clock) = make(focus: 10, repeating: false)

        clock.advance(10)
        vm.tick() // 완료

        #expect(vm.isComplete)
        // 시작 시 1번 + 완료 시 1번 이상 cancel.
        #expect(scheduler.cancelCount >= 1)
    }

    @Test func abortCancelsPendingNotification() {
        let (vm, scheduler, _) = make(focus: 60)

        vm.abort()

        #expect(scheduler.cancelCount >= 1)
    }

    // MARK: - 스냅샷 영속 / 복원 (앱 강제 종료 후 복원)

    private func makePersisting(
        focus: TimeInterval = 60,
        rest: TimeInterval = 30,
        clock: TestClock = TestClock(),
        spy: SnapshotSpy = SnapshotSpy()
    ) -> (FocusSessionViewModel, TestClock, SnapshotSpy) {
        let settings = FocusSettings(
            focusDuration: focus, restDuration: rest, isRepeating: true, cycleCount: 4
        )
        let vm = FocusSessionViewModel(
            settings: settings,
            scheduler: FakeFocusNotificationScheduler(),
            now: { clock.current },
            sessionID: UUID(),
            sessionTitle: "딥워크",
            colorHex: "#FF3B30",
            persist: { spy.persist($0) }
        )
        return (vm, clock, spy)
    }

    @Test func persistsSnapshotOnStart() {
        let (_, _, spy) = makePersisting(focus: 60)

        #expect(spy.last?.sessionTitle == "딥워크")
        #expect(spy.last?.phase == .focus)
        #expect(spy.last?.remaining == 60)
        #expect(spy.last?.isPaused == false)
    }

    @Test func persistsPausedSnapshotOnPause() {
        let (vm, _, spy) = makePersisting(focus: 60)

        vm.pause()

        #expect(spy.last?.isPaused == true)
        #expect(spy.last?.remaining == 60)
    }

    @Test func clearsSnapshotOnAbort() {
        let (vm, _, spy) = makePersisting(focus: 60)

        vm.abort()

        #expect(spy.clearedCount >= 1)
    }

    @Test func clearsSnapshotOnNaturalCompletion() {
        let clock = TestClock()
        let spy = SnapshotSpy()
        let settings = FocusSettings(
            focusDuration: 10, restDuration: 5, isRepeating: false, cycleCount: 1
        )
        let vm = FocusSessionViewModel(
            settings: settings, scheduler: FakeFocusNotificationScheduler(),
            now: { clock.current }, persist: { spy.persist($0) }
        )

        clock.advance(10)
        vm.tick() // 마지막 집중 종료 → 완료

        #expect(vm.isComplete)
        #expect(spy.clearedCount >= 1)
    }

    /// running 스냅샷 복원 — 절대 deadline 기반이라 다운타임만큼 벽시계로 정확히 이어진다.
    @Test func restoresRunningSnapshotByWallClock() {
        let clock = TestClock() // T0
        let snapshot = ActiveFocusSessionSnapshot(
            sessionID: UUID(), sessionTitle: "딥워크", colorHex: nil,
            settings: FocusSettings(focusDuration: 60, restDuration: 30, isRepeating: true, cycleCount: 4),
            phase: .focus, currentCycle: 2,
            phaseStartDate: Date(timeIntervalSinceReferenceDate: -20), // 시작은 과거
            phaseEndDate: Date(timeIntervalSinceReferenceDate: 40),    // T0+40에 종료
            isPaused: false, remaining: 40
        )
        let vm = FocusSessionViewModel(
            restoring: snapshot, scheduler: FakeFocusNotificationScheduler(),
            now: { clock.current }
        )

        #expect(vm.phase == .focus)
        #expect(vm.currentCycle == 2)
        #expect(vm.remaining == 40)

        clock.advance(10)
        vm.tick()
        #expect(vm.remaining == 30) // 다운타임/경과가 벽시계로 반영
    }

    /// paused 스냅샷 복원 — 잔여가 고정 source of truth, tick에도 안 줄어든다.
    @Test func restoresPausedSnapshotFrozen() {
        let clock = TestClock()
        let snapshot = ActiveFocusSessionSnapshot(
            sessionID: UUID(), sessionTitle: "딥워크", colorHex: nil,
            settings: FocusSettings(focusDuration: 60, restDuration: 30, isRepeating: true, cycleCount: 4),
            phase: .focus, currentCycle: 1,
            phaseStartDate: Date(timeIntervalSinceReferenceDate: 0),
            phaseEndDate: Date(timeIntervalSinceReferenceDate: 0),
            isPaused: true, remaining: 25
        )
        let vm = FocusSessionViewModel(
            restoring: snapshot, scheduler: FakeFocusNotificationScheduler(),
            now: { clock.current }
        )

        #expect(vm.isPaused)
        #expect(vm.remaining == 25)

        clock.advance(10)
        vm.tick()
        #expect(vm.remaining == 25) // 정지 — 그대로
    }
}

/// 스냅샷 영속 hook의 테스트 spy. 마지막 저장값과 삭제(nil) 호출 수를 기록.
final class SnapshotSpy: @unchecked Sendable {
    private(set) var last: ActiveFocusSessionSnapshot?
    private(set) var saveCount = 0
    private(set) var clearedCount = 0

    func persist(_ snapshot: ActiveFocusSessionSnapshot?) {
        if let snapshot {
            last = snapshot
            saveCount += 1
        } else {
            clearedCount += 1
        }
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
