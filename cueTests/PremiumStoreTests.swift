//
//  PremiumStoreTests.swift
//  cueTests
//

import Testing
@testable import cue

@MainActor
struct PremiumStoreTests {

    private static let monthlyID = "azhy.cue.premium.monthly"

    // MARK: - 상품 로드

    /// 상품 로드가 빈 배열(실패 폴백)이면 productsLoadFailed를 기록한다.
    @Test func startWithEmptyProductsLogsLoadFailed() async {
        let analytics = SpyAnalyticsService()
        let store = PremiumStore(service: FakePurchaseService(), analytics: analytics)

        await store.start()

        #expect(analytics.events.contains(.productsLoadFailed))
    }

    /// 상품이 정상 로드되면 productsLoadFailed를 기록하지 않는다.
    @Test func startWithProductsDoesNotLogLoadFailed() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900")]
        let store = PremiumStore(service: service, analytics: analytics)

        await store.start()

        #expect(!analytics.events.contains(.productsLoadFailed))
    }

    // MARK: - 엔타이틀먼트 변경

    /// 변경 스트림에서 isPremium 값이 실제로 바뀔 때만 entitlementChanged를 기록한다 —
    /// 같은 판정이 반복 방출돼도 중복 기록하지 않는다.
    @Test func entitlementStreamLogsOnlyRealChanges() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900")]
        service.entitlementUpdatesSequence = [[], [Self.monthlyID], [Self.monthlyID], []]
        let store = PremiumStore(service: service, analytics: analytics)

        await store.start()
        // 비구조 updatesTask가 스트림을 소진할 때까지 메인 액터에 양보한다.
        for _ in 0..<50 { await Task.yield() }

        #expect(analytics.events.filter { $0.name == "entitlement_changed" } == [
            .entitlementChanged(premium: true),
            .entitlementChanged(premium: false),
        ])
        #expect(store.isPremium == false)
    }

    // MARK: - 복원

    /// 복원 후 프리미엄이면 restoreResult(outcome: "success")를 기록한다.
    @Test func restoreLogsSuccessWhenPremium() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: analytics)

        await store.restore()

        #expect(analytics.events == [.restoreResult(outcome: "success")])
        #expect(store.isPremium == true)
    }

    /// 복원 후에도 비프리미엄이면 restoreResult(outcome: "failure")를 기록한다.
    @Test func restoreLogsFailureWhenNotPremium() async {
        let analytics = SpyAnalyticsService()
        let store = PremiumStore(service: FakePurchaseService(), analytics: analytics)

        await store.restore()

        #expect(analytics.events == [.restoreResult(outcome: "failure")])
        #expect(store.isPremium == false)
    }
}

// MARK: - 구매 서비스 더블 — 엔타이틀먼트·스트림을 시나리오대로 방출한다.

private final class FakePurchaseService: PurchaseService, @unchecked Sendable {
    var products: [PurchasableProduct] = []
    var entitled: Set<String> = []
    /// entitlementUpdates()가 순서대로 방출할 집합들 — 소진 후 스트림 종료.
    var entitlementUpdatesSequence: [Set<String>] = []

    func loadProducts() async -> [PurchasableProduct] { products }
    func purchase(productID: String) async throws -> PurchaseOutcome { .userCancelled }
    func restore() async {}
    func currentEntitlements() async -> Set<String> { entitled }
    func entitlementUpdates() -> AsyncStream<Set<String>> {
        let sequence = entitlementUpdatesSequence
        return AsyncStream { continuation in
            for ids in sequence { continuation.yield(ids) }
            continuation.finish()
        }
    }
}

// MARK: - 분석 이벤트 기록용 더블

/// `log(_:)`가 동기라 actor를 못 쓴다 — 테스트는 MainActor 단일 스레드라 @unchecked로 안전.
private final class SpyAnalyticsService: AnalyticsService, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func log(name: String, parameters: [String: String]) {}
}
