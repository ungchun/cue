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

    // MARK: - 토스트의 귀속 (시트 위 중복·잔상 방지)

    /// 오버레이가 하나뿐이면 그게 그린다.
    @Test func singleHostRenders() {
        let center = ToastCenter()
        let root = UUID()
        center.registerHost(root)

        center.show("Live")

        #expect(center.shouldRender(host: root))
    }

    /// 시트가 떠 있을 때 뜬 토스트는 **시트만** 그린다 — 루트까지 그리면 `.large` 시트
    /// 위쪽 틈으로 삐져나와 토스트가 둘로 보인다.
    @Test func toastBelongsToTopmostHostAtShowTime() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()
        center.registerHost(root)
        center.registerHost(sheet)

        center.showPremium()

        #expect(center.shouldRender(host: sheet))
        #expect(center.shouldRender(host: root) == false)
    }

    /// 토스트가 떠 있는 채로 시트를 내리면 **토스트도 함께 사라진다.**
    /// 넘겨주면 사용자가 시트를 닫자마자 뒤 화면에 토스트가 불쑥 나타난다 —
    /// 자기가 방금 떠난 맥락의 안내가 엉뚱한 화면에서 되살아나는 셈이다.
    @Test func toastDiesWithItsHost() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()
        center.registerHost(root)
        center.registerHost(sheet)
        center.showPremium()

        center.unregisterHost(sheet)

        #expect(center.isPresented == false)
        #expect(center.shouldRender(host: root) == false)
    }

    /// 주인이 아닌 오버레이가 사라지는 건 토스트에 영향을 주지 않는다.
    @Test func unrelatedHostLeavingKeepsToast() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()
        center.registerHost(root)
        center.registerHost(sheet)
        center.showPremium()

        center.unregisterHost(root)

        #expect(center.isPresented == true)
        #expect(center.shouldRender(host: sheet))
    }

    /// 시트가 닫힌 **뒤에** 뜬 토스트는 루트가 정상적으로 그린다 — 귀속은 표시 시점에 정해진다.
    @Test func hostFallsBackForLaterToasts() {
        let center = ToastCenter()
        let root = UUID()
        let sheet = UUID()
        center.registerHost(root)
        center.registerHost(sheet)
        center.unregisterHost(sheet)

        center.show("Live")

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
        center.show("Live")

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
