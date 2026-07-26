//
//  StoreKitPurchaseService.swift
//  cue / Data
//
//  StoreKit 2 구현 — Product 조회·구매·복원·엔타이틀먼트 관찰. 외부 프레임워크 경계 글루라
//  RED 면제(빌드·실행·Sandbox로 검증). 판정 로직은 Domain(`PremiumEntitlement`)에 있다.
//

import Foundation
import StoreKit

struct StoreKitPurchaseService: PurchaseService {

    func loadProducts() async -> [PurchasableProduct] {
        do {
            let products = try await Product.products(for: PremiumProduct.allIDs)
            var result: [PurchasableProduct] = []
            for product in products {
                var trialDays: Int?
                var eligible = false
                // 무료 체험만 트라이얼로 취급 — pay-as-you-go/pay-up-front 인트로는 표시하지 않는다.
                if let subscription = product.subscription,
                   let intro = subscription.introductoryOffer,
                   intro.paymentMode == .freeTrial {
                    trialDays = Self.days(from: intro.period)
                    // 자격은 구독 그룹당 1회 — 재구독자에게 "무료" 문구를 숨기는 근거.
                    eligible = await subscription.isEligibleForIntroOffer
                }
                result.append(PurchasableProduct(
                    id: product.id,
                    displayPrice: product.displayPrice,
                    trialDays: trialDays,
                    isTrialEligible: eligible
                ))
            }
            return result
        } catch {
            return []
        }
    }

    /// 구독 기간을 표시용 일수로 환산. 월·년은 근사값(30·365) — 현재 오퍼는 P1W라 정확값이다.
    private static func days(from period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: period.value
        }
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        guard let product = try await Product.products(for: [productID]).first else {
            return .userCancelled
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // 검증된 트랜잭션만 반영하고 finish로 큐에서 제거한다.
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func restore() async {
        // App Store 계정과 동기화 — 이후 currentEntitlements/updates가 복원된 구매를 반영한다.
        try? await AppStore.sync()
    }

    func currentEntitlements() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            if transaction.revocationDate == nil, PremiumProduct.allIDs.contains(transaction.productID) {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }

    func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let task = Task {
                // 구매/갱신/환불 등 트랜잭션 변화가 올 때마다 최신 엔타이틀먼트 집합을 방출.
                for await update in Transaction.updates {
                    if let transaction = try? Self.checkVerified(update) {
                        await transaction.finish()
                    }
                    continuation.yield(await currentEntitlements())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// StoreKit 서명 검증 — 위조 트랜잭션(`.unverified`)은 오류로 처리한다.
    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }
}
