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
        let store = PremiumStore(service: FakePurchaseService(), analytics: analytics,
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.start()

        #expect(analytics.events.contains(.productsLoadFailed))
    }

    /// 상품이 정상 로드되면 productsLoadFailed를 기록하지 않는다.
    @Test func startWithProductsDoesNotLogLoadFailed() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900")]
        let store = PremiumStore(service: service, analytics: analytics,
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.start()

        #expect(!analytics.events.contains(.productsLoadFailed))
    }

    // MARK: - 트라이얼 표시

    /// 로드된 상품에 자격 있는 트라이얼이 있으면 해당 플랜의 표시 일수를 돌려준다.
    @Test func trialDaysReturnsDaysForEligibleProduct() async {
        let service = FakePurchaseService()
        service.products = [
            PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                               trialDays: 7, isTrialEligible: true),
            PurchasableProduct(id: "azhy.cue.premium.lifetime", displayPrice: "₩44,000"),
        ]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.start()

        #expect(store.trialDays(for: .monthly) == 7)
        #expect(store.trialDays(for: .lifetime) == nil)
    }

    /// 페이월 재진입 재로드 — 자격이 바뀌면(타 기기 체험 소진 등) 표시가 따라간다.
    @Test func reloadProductsRefreshesTrialEligibility() async {
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                                               trialDays: 7, isTrialEligible: true)]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)
        await store.start()
        #expect(store.trialDays(for: .monthly) == 7)

        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                                               trialDays: 7, isTrialEligible: false)]
        await store.reloadProducts()

        #expect(store.trialDays(for: .monthly) == nil)
    }

    /// 재로드 실패(빈 배열 폴백)면 기존 캐시를 유지한다 — CTA가 통째로 사라지지 않게.
    @Test func reloadProductsKeepsCacheOnFailure() async {
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900",
                                               trialDays: 7, isTrialEligible: true)]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)
        await store.start()

        service.products = []
        await store.reloadProducts()

        #expect(store.trialDays(for: .monthly) == 7)
    }

    /// 상품 미로드(빈 배열 폴백) 상태에서는 어떤 플랜도 트라이얼을 표시하지 않는다.
    @Test func trialDaysReturnsNilBeforeProductsLoad() {
        let store = PremiumStore(service: FakePurchaseService(), analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)

        #expect(store.trialDays(for: .yearly) == nil)
    }

    // MARK: - 엔타이틀먼트 변경

    /// 변경 스트림에서 isPremium 값이 실제로 바뀔 때만 entitlementChanged를 기록한다 —
    /// 같은 판정이 반복 방출돼도 중복 기록하지 않는다.
    @Test func entitlementStreamLogsOnlyRealChanges() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.products = [PurchasableProduct(id: Self.monthlyID, displayPrice: "₩2,900")]
        service.entitlementUpdatesSequence = [[], [Self.monthlyID], [Self.monthlyID], []]
        let store = PremiumStore(service: service, analytics: analytics,
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.start()
        // 비구조 updatesTask가 스트림을 소진할 때까지 메인 액터에 양보한다.
        for _ in 0..<50 { await Task.yield() }

        #expect(analytics.events.filter { $0.name == "entitlement_changed" } == [
            .entitlementChanged(premium: true),
            .entitlementChanged(premium: false),
        ])
        #expect(store.isPremium == false)
    }

    // MARK: - 판정 신뢰도

    /// 조회가 신뢰 불가(nil)면 기존 isPremium을 유지하고 확정 판정도 내리지 않는다 —
    /// 일시적 조회 실패가 유료 사용자를 강등시키면 안 된다.
    @Test func refreshWithUnavailableVerdictKeepsPremiumState() async {
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)
        await store.refresh()
        #expect(store.isPremium == true)

        service.entitled = nil
        await store.refresh()

        #expect(store.isPremium == true)
        #expect(store.confirmedIsPremium == nil)
    }

    /// 빈 집합(확정 미보유)은 확정 무료 판정 — 강등 정리의 실행 조건이 된다.
    @Test func refreshWithEmptyEntitlementsConfirmsFree() async {
        let service = FakePurchaseService()
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.refresh()

        #expect(store.isPremium == false)
        #expect(store.confirmedIsPremium == false)
    }

    /// 보유 확인은 확정 유료 판정 — 접어둔 설정 자동 복구의 실행 조건이 된다.
    @Test func refreshWithEntitlementsConfirmsPremium() async {
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.refresh()

        #expect(store.isPremium == true)
        #expect(store.confirmedIsPremium == true)
    }

    // MARK: - App Group 미러
    //
    // 위젯은 이 미러만 보고 잠금을 정한다. 테스트는 진짜 App Group 대신 인스턴스별 스파이를
    // 주입한다 — 전역을 건드리면 병렬 실행에서 서로의 값을 덮고 개발 기기에 잔여값이 남는다.

    /// 확정 유료 판정이면 위젯이 읽는 미러에 그대로 쓴다.
    ///
    /// 미러 쓰기가 RootView의 `onChange`(값 **변화**)에만 있으면, 판정이 바뀌지 않는
    /// 실행에서는 한 번도 쓰이지 않는다. 미러 기본값은 false라 그 상태의 유료 사용자에게
    /// 위젯 잠금이 뜬다 — 앱은 유료로 보이는데 위젯만 잠기는 증상. 확정될 때마다 쓴다.
    @Test func refreshMirrorsConfirmedPremiumToAppGroup() async {
        let mirror = SpyMirror(initial: false)
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: mirror.premiumMirror)

        await store.refresh()

        #expect(mirror.value == true)
        #expect(mirror.reloadCount == 1)
    }

    /// 확정 무료 판정이면 미러도 false로 내린다 — 만료 후 잠금이 다시 걸려야 한다.
    @Test func refreshMirrorsConfirmedFreeToAppGroup() async {
        let mirror = SpyMirror(initial: true)
        let store = PremiumStore(service: FakePurchaseService(), analytics: SpyAnalyticsService(),
                                 mirror: mirror.premiumMirror)

        await store.refresh()

        #expect(mirror.value == false)
    }

    /// 판정 불가(nil)면 미러를 건드리지 않는다 — 일시적 조회 실패로 유료 사용자의
    /// 위젯이 잠기면 안 된다. 직전 확정값이 그대로 남아야 한다.
    @Test func refreshWithUnavailableVerdictLeavesMirrorUntouched() async {
        let mirror = SpyMirror(initial: true)
        let service = FakePurchaseService()
        service.entitled = nil
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: mirror.premiumMirror)

        await store.refresh()

        #expect(mirror.value == true)
        #expect(mirror.reloadCount == 0)
    }

    /// 미러가 이미 맞으면 위젯을 다시 그리지 않는다 — refresh는 포그라운드마다 도는데
    /// 매번 리로드하면 위젯 예산만 태운다.
    @Test func refreshDoesNotReloadWidgetsWhenMirrorAlreadyCorrect() async {
        let mirror = SpyMirror(initial: true)
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: mirror.premiumMirror)

        await store.refresh()
        await store.refresh()

        #expect(mirror.value == true)
        #expect(mirror.reloadCount == 0)
    }

    /// 갱신·환불 스트림의 확정 판정도 미러에 반영된다.
    @Test func entitlementStreamMirrorsToAppGroup() async {
        let mirror = SpyMirror(initial: false)
        let service = FakePurchaseService()
        service.entitlementUpdatesSequence = [[Self.monthlyID]]
        let store = PremiumStore(service: service, analytics: SpyAnalyticsService(),
                                 mirror: mirror.premiumMirror)

        await store.start()
        for _ in 0..<50 { await Task.yield() }

        #expect(mirror.value == true)
    }

    // MARK: - 복원

    /// 복원 후 프리미엄이면 restoreResult(outcome: "success")를 기록한다.
    @Test func restoreLogsSuccessWhenPremium() async {
        let analytics = SpyAnalyticsService()
        let service = FakePurchaseService()
        service.entitled = [Self.monthlyID]
        let store = PremiumStore(service: service, analytics: analytics,
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.restore()

        #expect(analytics.events == [.restoreResult(outcome: "success")])
        #expect(store.isPremium == true)
    }

    /// 복원 후에도 비프리미엄이면 restoreResult(outcome: "failure")를 기록한다.
    @Test func restoreLogsFailureWhenNotPremium() async {
        let analytics = SpyAnalyticsService()
        let store = PremiumStore(service: FakePurchaseService(), analytics: analytics,
                                 mirror: SpyMirror(initial: false).premiumMirror)

        await store.restore()

        #expect(analytics.events == [.restoreResult(outcome: "failure")])
        #expect(store.isPremium == false)
    }
}

// MARK: - 구매 서비스 더블 — 엔타이틀먼트·스트림을 시나리오대로 방출한다.

private final class FakePurchaseService: PurchaseService, @unchecked Sendable {
    var products: [PurchasableProduct] = []
    /// nil = 조회 신뢰 불가(서명 검증 실패 등) — 실서비스의 "대답 못 받음"을 흉내낸다.
    var entitled: Set<String>? = []
    /// entitlementUpdates()가 순서대로 방출할 집합들 — 소진 후 스트림 종료.
    var entitlementUpdatesSequence: [Set<String>] = []

    func loadProducts() async -> [PurchasableProduct] { products }
    func purchase(productID: String) async throws -> PurchaseOutcome { .userCancelled }
    func restore() async {}
    func currentEntitlements() async -> Set<String>? { entitled }
    func entitlementUpdates() -> AsyncStream<Set<String>> {
        let sequence = entitlementUpdatesSequence
        return AsyncStream { continuation in
            for ids in sequence { continuation.yield(ids) }
            continuation.finish()
        }
    }
}

// MARK: - App Group 미러 더블 — 전역 대신 인스턴스에 값을 담아 테스트를 격리한다.

/// 위젯 미러의 읽기·쓰기·리로드를 가로채 기록한다. 테스트는 MainActor 단일 스레드라
/// @unchecked로 안전하다(다른 더블과 같은 이유).
private final class SpyMirror: @unchecked Sendable {
    private(set) var value: Bool
    /// 위젯 리로드가 몇 번 나갔는지 — 불필요한 리로드(위젯 예산 낭비)를 잡는다.
    private(set) var reloadCount = 0

    init(initial: Bool) {
        self.value = initial
    }

    var premiumMirror: PremiumMirror {
        PremiumMirror(
            read: { [self] in value },
            write: { [self] in value = $0 },
            reloadWidgets: { [self] in reloadCount += 1 }
        )
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
