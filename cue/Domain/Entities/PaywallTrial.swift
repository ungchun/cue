//
//  PaywallTrial.swift
//  cue / Domain
//

/// 페이월에 무료 체험 문구를 보여줄지 판정하는 순수 로직.
/// "트라이얼이 존재하고 + 이 사용자가 자격이 있을 때"만 일수를 돌려준다 —
/// 자격 없는 사용자(재구독자)에게 "무료"를 보여주면 결제 시점에 배신감이 되기 때문.
enum PaywallTrial {
    /// 해당 상품에 표시할 무료 체험 일수. 표시하면 안 되면 nil.
    static func displayDays(for productID: String, in products: [PurchasableProduct]) -> Int? {
        guard let product = products.first(where: { $0.id == productID }),
              product.isTrialEligible else { return nil }
        return product.trialDays
    }
}
