//
//  ToastCenterTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

@MainActor
struct ToastCenterTests {

    /// 일반 토스트는 탭 대상이 아니다 — handleTap이 핸들러를 부르지 않고 토스트도 유지된다
    /// (일반 토스트엔 탭 제스처 자체를 안 붙이지만, 방어적으로 no-op을 보장).
    @Test func plainToastIsNotTappable() {
        let center = ToastCenter()
        var opened = false
        center.premiumTapHandler = { opened = true }

        center.show("Live")

        #expect(center.isPremiumToast == false)
        center.handleTap()
        #expect(opened == false)
        #expect(center.isPresented == true)
    }

    /// showPremium은 프리미엄 토스트로 표시된다 — 오버레이가 탭 제스처를 붙이는 기준.
    @Test func showPremiumMarksToastTappable() {
        let center = ToastCenter()

        center.showPremium()

        #expect(center.isPresented == true)
        #expect(center.isPremiumToast == true)
    }

    /// 프리미엄 토스트 탭 → 토스트를 닫고 핸들러(페이월 열기)를 부른다.
    @Test func premiumToastTapDismissesAndOpensPaywall() {
        let center = ToastCenter()
        var opened = false
        center.premiumTapHandler = { opened = true }

        center.showPremium()
        center.handleTap()

        #expect(opened == true)
        #expect(center.isPresented == false)
    }

    /// 프리미엄 토스트 뒤에 일반 토스트가 오면 프리미엄 표시가 풀린다 —
    /// 낡은 탭 제스처가 다음 토스트에 남으면 안 된다.
    @Test func plainToastAfterPremiumClearsTappable() {
        let center = ToastCenter()

        center.showPremium()
        center.show("Live")

        #expect(center.isPremiumToast == false)
    }

    /// 스와이프 등 명시적 dismiss 후에는 탭이 와도 핸들러를 부르지 않는다.
    @Test func tapAfterDismissDoesNothing() {
        let center = ToastCenter()
        var opened = false
        center.premiumTapHandler = { opened = true }

        center.showPremium()
        center.dismiss()
        center.handleTap()

        #expect(opened == false)
    }
}
