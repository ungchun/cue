//
//  PaywallTrialTests.swift
//  cueTests
//

import Testing
@testable import cue

struct PaywallTrialTests {

    private static let monthlyID = "azhy.cue.premium.monthly"
    private static let lifetimeID = "azhy.cue.premium.lifetime"

    /// 트라이얼이 있고 자격도 있으면 표시 일수를 돌려준다.
    @Test func eligibleTrialReturnsDays() {
        let products = [
            PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                               trialDays: 7, isTrialEligible: true)
        ]
        #expect(PaywallTrial.displayDays(for: Self.monthlyID, in: products) == 7)
    }

    /// 트라이얼은 있지만 자격이 없으면(재구독자) 표시하지 않는다 —
    /// 자격 없는 사용자에게 "무료"를 보여주면 결제 시 배신감이 된다.
    @Test func ineligibleTrialReturnsNil() {
        let products = [
            PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                               trialDays: 7, isTrialEligible: false)
        ]
        #expect(PaywallTrial.displayDays(for: Self.monthlyID, in: products) == nil)
    }

    /// 트라이얼 자체가 없는 상품(라이프타임)은 nil.
    @Test func productWithoutTrialReturnsNil() {
        let products = [
            PurchasableProduct(id: Self.lifetimeID, displayPrice: "₩44,000")
        ]
        #expect(PaywallTrial.displayDays(for: Self.lifetimeID, in: products) == nil)
    }

    /// 상품이 로드되지 않았으면(빈 배열 폴백) nil — placeholder 가격 상태에서 트라이얼 문구 금지.
    @Test func missingProductReturnsNil() {
        #expect(PaywallTrial.displayDays(for: Self.monthlyID, in: []) == nil)
    }
}
