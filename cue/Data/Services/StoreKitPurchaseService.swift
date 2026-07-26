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

    func currentEntitlements() async -> Set<String>? {
        var ids: Set<String> = []
        var sawUnverified = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else {
                sawUnverified = true
                continue
            }
            if transaction.revocationDate == nil, PremiumProduct.allIDs.contains(transaction.productID) {
                ids.insert(transaction.productID)
            }
        }
        return Self.entitlementSnapshot(verifiedIDs: ids, sawUnverified: sawUnverified)
    }

    /// 스냅샷 판정 — "확정"과 "판정 불가"를 가르는 정책. 뒤집히면 유료 사용자를 강등시키는
    /// 가장 위험한 한 줄이라 순수 함수로 분리해 테스트로 고정한다(EntitlementSnapshotTests).
    ///
    /// - 검증 실패만 있고 확인 보유가 없으면 nil(판정 불가) — 일시적 검증 실패(인증서·시계
    ///   문제 등)로 유료 사용자를 강등시키지 않는다.
    /// - 트랜잭션이 아예 없으면(0개) 빈 집합 = **확정 미보유**로 취급한다. 알려진 트레이드오프:
    ///   App Store 로그아웃·기기 복원 직후 등 "응답 부재"도 0개로 와서 오강등될 수 있으나,
    ///   0개를 판정 불가로 바꾸면 만료·신규 무료 사용자(정당한 0개)의 강등 정리가 영영 안 돈다.
    ///   로컬에선 둘을 구분할 수 없어 확정 쪽을 택하되, 오강등은 접어두기(demoted*) 기록 덕에
    ///   재로그인·재확인 시 자동 복구된다(파괴 아님 — ReconcilePremiumSettingsUseCase).
    static func entitlementSnapshot(verifiedIDs: Set<String>, sawUnverified: Bool) -> Set<String>? {
        if verifiedIDs.isEmpty, sawUnverified { return nil }
        return verifiedIDs
    }

    func entitlementUpdates() -> AsyncStream<Set<String>> {
        AsyncStream { continuation in
            let task = Task {
                // 구매/갱신/환불 등 트랜잭션 변화가 올 때마다 최신 엔타이틀먼트 집합을 방출.
                for await update in Transaction.updates {
                    if let transaction = try? Self.checkVerified(update) {
                        await transaction.finish()
                    }
                    // 신뢰 불가(nil) 스냅샷은 방출하지 않는다 — 스트림 구독자(PremiumStore)가
                    // 빈 집합으로 오인해 강등하는 것을 막고, 직전 판정을 유지시킨다.
                    if let ids = await currentEntitlements() {
                        continuation.yield(ids)
                    }
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
