//
//  PremiumStore.swift
//  cue / Presentation
//
//  프리미엄 엔타이틀먼트의 단일 반응형 소유자. 앱 루트가 하나 만들어 Environment로 주입하고,
//  게이트(설정·집중·라이브 쿼터)와 페이월이 이 값을 읽는다. 정적 `PremiumAccess`를 대체한다.
//

import Observation
import SwiftUI

@MainActor
@Observable
final class PremiumStore {
    /// 현재 프리미엄 여부 — 구매/복원/갱신/만료 시 자동 갱신. 게이트가 이 값을 읽는다.
    private(set) var isPremium: Bool = false
    /// 페이월에 표시할 상품(가격) 목록.
    private(set) var products: [PurchasableProduct] = []

    private let service: any PurchaseService
    private var updatesTask: Task<Void, Never>?

    /// 저장 프로퍼티만 세팅하므로 nonisolated — Environment `@Entry` 기본값 등 비격리 컨텍스트에서도
    /// 생성 가능하게 한다(엔타이틀먼트 로드는 `start()`에서 main actor로 수행).
    nonisolated init(service: any PurchaseService) {
        self.service = service
    }

    /// 프리뷰·테스트 편의 — 비동기 로드 없이 초기 프리미엄 상태를 즉시 세팅한다.
    convenience init(previewIsPremium: Bool) {
        self.init(service: DisabledPurchaseService())
        self.isPremium = previewIsPremium
    }

    /// 앱 시작 시 1회 — 상품 로드 + 현재 엔타이틀먼트 반영 + 변경 스트림 구독.
    func start() async {
        products = await service.loadProducts()
        await refresh()
        updatesTask = Task { [weak self] in
            guard let stream = self?.service.entitlementUpdates() else { return }
            for await ids in stream {
                self?.isPremium = PremiumEntitlement.isPremium(entitledProductIDs: ids)
            }
        }
    }

    /// 현재 보유 엔타이틀먼트로 프리미엄 상태를 다시 계산한다.
    func refresh() async {
        let ids = await service.currentEntitlements()
        isPremium = PremiumEntitlement.isPremium(entitledProductIDs: ids)
    }

    /// 구매 시도 — 성공 시 즉시 엔타이틀먼트를 재확인해 잠금을 푼다.
    @discardableResult
    func purchase(_ productID: String) async -> PurchaseOutcome {
        let outcome = (try? await service.purchase(productID: productID)) ?? .userCancelled
        if outcome == .success { await refresh() }
        return outcome
    }

    /// 이전 구매 복원.
    func restore() async {
        await service.restore()
        await refresh()
    }

    /// 특정 상품의 가격 표시 문자열(로드된 경우).
    func displayPrice(for product: PremiumProduct) -> String? {
        products.first { $0.id == product.id }?.displayPrice
    }
    // 앱 수명 동안 사는 단일 인스턴스라 별도 deinit 취소는 두지 않는다(프로세스 종료 시 함께 정리).
}

extension EnvironmentValues {
    /// 기본값은 no-op 서비스 기반 — 프리뷰가 StoreKit 없이 동작한다(항상 비프리미엄).
    @Entry var premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService())
}
