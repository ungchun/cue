//
//  ForcedUpdateTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 강제 업데이트 판정 — Remote Config의 최소 버전과 현재 버전을 비교한다.
/// 원칙: 판정 불가(파싱 실패·설정 없음·네트워크 실패=nil)는 **열어준다(fail-open)** —
/// 강제 업데이트는 잘못 잠그면 앱 전체가 벽돌이 되므로 확실할 때만 잠근다.
struct ForcedUpdateTests {

    // MARK: - AppVersion 파싱

    @Test func parsesDottedVersion() {
        #expect(AppVersion("1.0.0") != nil)
        #expect(AppVersion("2.15") != nil)
        #expect(AppVersion("3") != nil)
    }

    @Test func rejectsInvalidVersion() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("abc") == nil)
        #expect(AppVersion("1.a.0") == nil)
        #expect(AppVersion("1..0") == nil)
        #expect(AppVersion("-1.0") == nil)
    }

    // MARK: - AppVersion 비교

    /// 자릿수가 달라도 의미가 같으면 같은 버전 — "1.0"과 "1.0.0".
    @Test func equalityIgnoresTrailingZeros() {
        #expect(AppVersion("1.0")! == AppVersion("1.0.0")!)
        #expect(AppVersion("1")! == AppVersion("1.0.0")!)
        #expect(AppVersion("1.0.1")! != AppVersion("1.0")!)
    }

    /// 숫자 단위 비교 — 문자열 비교가 아니므로 "1.10" > "1.9".
    @Test func comparesNumericallyPerComponent() {
        #expect(AppVersion("1.10.0")! > AppVersion("1.9.9")!)
        #expect(AppVersion("2.0")! > AppVersion("1.99.99")!)
        #expect(AppVersion("1.0.0")! < AppVersion("1.0.1")!)
        #expect(AppVersion("1.2")! < AppVersion("1.2.1")!)
    }

    // MARK: - 판정 유스케이스

    private struct StubPolicy: AppUpdatePolicyService {
        let minimum: AppVersion?
        func minimumRequiredVersion() async -> AppVersion? { minimum }
    }

    /// 현재 버전이 최소 요구보다 낮으면 강제 업데이트 필요.
    @Test func requiresUpdateWhenBelowMinimum() async {
        let check = CheckForcedUpdateUseCase(service: StubPolicy(minimum: AppVersion("1.1.0")))
        #expect(await check(currentVersion: "1.0.0") == true)
    }

    /// 같거나 높으면 통과.
    @Test func allowsWhenEqualOrAbove() async {
        let check = CheckForcedUpdateUseCase(service: StubPolicy(minimum: AppVersion("1.1.0")))
        #expect(await check(currentVersion: "1.1.0") == false)
        #expect(await check(currentVersion: "1.1") == false)
        #expect(await check(currentVersion: "1.2.0") == false)
    }

    /// 최소 버전 미설정(nil) — 잠그지 않는다.
    @Test func allowsWhenNoMinimumConfigured() async {
        let check = CheckForcedUpdateUseCase(service: StubPolicy(minimum: nil))
        #expect(await check(currentVersion: "1.0.0") == false)
    }

    /// 현재 버전 파싱 실패 — 잠그지 않는다(fail-open).
    @Test func allowsWhenCurrentVersionUnparsable() async {
        let check = CheckForcedUpdateUseCase(service: StubPolicy(minimum: AppVersion("9.0.0")))
        #expect(await check(currentVersion: "not-a-version") == false)
    }
}
