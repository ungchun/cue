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

    // MARK: - 호스트 스택 (시트 위 중복 방지)

    /// 오버레이가 하나뿐이면 그게 그린다.
    @Test func singleHostRenders() {
        let center = ToastCenter()
        let root = UUID()

        center.registerHost(root)

        #expect(center.shouldRender(host: root))
    }

    /// 시트가 올라오면 **나중에 등록된 쪽만** 그린다 — 루트 오버레이는 시트 아래에 깔려
    /// `.large` 시트 위쪽 틈으로 삐져나와 토스트가 둘로 보인다.
    @Test func topmostHostWins() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()

        center.registerHost(root)
        center.registerHost(sheet)

        #expect(center.shouldRender(host: sheet))
        #expect(center.shouldRender(host: root) == false)
    }

    /// 시트가 닫히면 루트가 다시 그린다.
    @Test func hostFallsBackWhenTopUnregisters() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()

        center.registerHost(root)
        center.registerHost(sheet)
        center.unregisterHost(sheet)

        #expect(center.shouldRender(host: root))
    }

    /// 해제 순서가 뒤집혀도 안전하다 — SwiftUI는 새 시트의 onAppear가 이전 시트의
    /// onDisappear보다 먼저 올 수 있어, 스택을 순서가 아니라 **id로** 지운다.
    @Test func outOfOrderUnregisterKeepsTopmost() {
        let center = ToastCenter()
        let root = UUID()
        let first = UUID()
        let second = UUID()

        center.registerHost(root)
        center.registerHost(first)
        center.registerHost(second)
        center.unregisterHost(first)

        #expect(center.shouldRender(host: second))
        #expect(center.shouldRender(host: root) == false)
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
