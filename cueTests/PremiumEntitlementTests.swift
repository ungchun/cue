//
//  PremiumEntitlementTests.swift
//  cueTests
//

import Testing
@testable import cue

/// 엔타이틀먼트 → 프리미엄 판정. 구독 활성이든 평생 구매든, 프리미엄 상품 하나라도 있으면 true.
struct PremiumEntitlementTests {

    @Test func monthlyEntitlementIsPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: ["azhy.cue.premium.monthly"]))
    }

    @Test func yearlyEntitlementIsPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: ["azhy.cue.premium.yearly"]))
    }

    @Test func lifetimeEntitlementIsPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: ["azhy.cue.premium.lifetime"]))
    }

    @Test func noEntitlementIsNotPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: []) == false)
    }

    @Test func unknownProductIsNotPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: ["com.other.thing"]) == false)
    }

    @Test func mixOfKnownAndUnknownIsPremium() {
        #expect(PremiumEntitlement.isPremium(entitledProductIDs: ["com.other.thing", "azhy.cue.premium.yearly"]))
    }
}
