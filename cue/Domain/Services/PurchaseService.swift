//
//  PurchaseService.swift
//  cue / Domain
//

/// 인앱 구매 추상화 — Domain은 StoreKit을 모른다. 구체 구현(`StoreKitPurchaseService`)이
/// Data 계층에서 StoreKit 2(`Product`, `Transaction`)를 다룬다.
///
/// 엔타이틀먼트는 "현재 보유한 프리미엄 상품 ID 집합"으로 표현한다 — 구독 활성이면 그 구독 ID가,
/// 평생 구매면 그 ID가 포함된다. 판정은 `PremiumEntitlement.isPremium`이 담당.
protocol PurchaseService: Sendable {
    /// 판매 상품(가격 표시 문자열 등) 로드. 실패하면 빈 배열.
    func loadProducts() async -> [PurchasableProduct]

    /// 구매 시도. 결과는 성공/취소/대기. 성공 시 엔타이틀먼트는 `entitlementUpdates`로도 반영된다.
    func purchase(productID: String) async throws -> PurchaseOutcome

    /// 이전 구매 복원 — `AppStore.sync()`로 App Store 계정과 동기화한다.
    func restore() async

    /// 현재 보유한 프리미엄 엔타이틀먼트 상품 ID 집합.
    /// **빈 집합 = 확정 미보유**, **nil = 조회 신뢰 불가**(서명 검증 실패 등) — 호출부는
    /// nil이면 기존 판정을 유지해야 한다. 둘을 뭉개면 일시적 실패가 유료 사용자를 강등시킨다.
    func currentEntitlements() async -> Set<String>?

    /// 엔타이틀먼트 변경 스트림 — 구매/갱신/만료/환불 시 최신 상품 ID 집합을 방출한다.
    func entitlementUpdates() -> AsyncStream<Set<String>>
}

/// 페이월에 표시할 상품 — StoreKit `Product`의 표시용 스냅샷.
struct PurchasableProduct: Identifiable, Sendable, Equatable {
    /// productID(= `PremiumProduct.id`).
    let id: String
    /// 로케일·통화가 적용된 가격 문자열(예: "₩2,900"). StoreKit `displayPrice`.
    let displayPrice: String
    /// 무료 체험 기간(일). 인트로 오퍼가 무료 체험이 아니거나 없으면 nil.
    let trialDays: Int?
    /// 이 사용자가 인트로 오퍼를 받을 자격이 있는가 — 구독 그룹당 1회라 재구독자는 false.
    let isTrialEligible: Bool

    init(id: String, displayPrice: String, trialDays: Int? = nil, isTrialEligible: Bool = false) {
        self.id = id
        self.displayPrice = displayPrice
        self.trialDays = trialDays
        self.isTrialEligible = isTrialEligible
    }
}

/// 구매 시도 결과.
enum PurchaseOutcome: Sendable, Equatable {
    case success
    case userCancelled
    case pending
}
