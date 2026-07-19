//
//  DisabledPurchaseService.swift
//  cue / Data
//
//  프리뷰·테스트용 no-op 구매 서비스 — StoreKit 없이 페이월/게이트가 동작한다.
//  기본은 "구매 없음"(비프리미엄). 필요 시 `entitled`로 프리미엄 상태를 흉내낼 수 있다.
//

import Foundation

struct DisabledPurchaseService: PurchaseService {
    var entitled: Set<String> = []
    var products: [PurchasableProduct] = []

    func loadProducts() async -> [PurchasableProduct] { products }
    func purchase(productID: String) async throws -> PurchaseOutcome { .userCancelled }
    func restore() async {}
    func currentEntitlements() async -> Set<String> { entitled }
    func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { $0.finish() }
    }
}
