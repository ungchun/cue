//
//  PremiumProduct.swift
//  cue / Domain
//

/// Cue Premium 상품 — App Store Connect에 등록된 3개 상품과 1:1 대응.
/// productID는 ASC 등록값과 정확히 일치해야 한다(StoreKit 조회 키).
enum PremiumProduct: String, CaseIterable, Sendable {
    case monthly = "azhy.cue.premium.monthly"
    case yearly = "azhy.cue.premium.yearly"
    case lifetime = "azhy.cue.premium.lifetime"

    var id: String { rawValue }

    /// 모든 프리미엄 상품 ID 집합 — 엔타이틀먼트 판정 기준.
    static var allIDs: Set<String> { Set(allCases.map(\.id)) }
}

/// 현재 보유한 엔타이틀먼트로 프리미엄 여부를 판정하는 순수 로직.
/// StoreKit `Transaction.currentEntitlements`가 준 활성 상품 ID 집합을 받아, 그중 하나라도
/// 프리미엄 상품이면 프리미엄으로 본다(구독 활성 OR 평생 구매).
enum PremiumEntitlement {
    static func isPremium(entitledProductIDs: Set<String>) -> Bool {
        !entitledProductIDs.isDisjoint(with: PremiumProduct.allIDs)
    }
}
