//
//  PremiumStore.swift
//  cue / Presentation
//
//  프리미엄 엔타이틀먼트의 단일 반응형 소유자. 앱 루트가 하나 만들어 Environment로 주입하고,
//  게이트(설정·집중·라이브 쿼터)와 페이월이 이 값을 읽는다. 정적 `PremiumAccess`를 대체한다.
//

import Observation
import SwiftUI
import WidgetKit

/// 확정 판정을 위젯에 흘리는 통로 — App Group 미러 읽기·쓰기와 위젯 리로드.
///
/// 실제 구현은 전역 `SharedAppGroup`과 `WidgetCenter`를 건드리는 프로세스 밖 부수효과라,
/// 테스트가 진짜 미러를 오염시키지 않도록(그리고 병렬 실행에서 서로 간섭하지 않도록)
/// 이 좁은 통로 하나만 주입 가능하게 둔다.
struct PremiumMirror: Sendable {
    var read: @Sendable () -> Bool
    var write: @Sendable (Bool) -> Void
    var reloadWidgets: @Sendable () -> Void

    /// 프로덕션 통로 — 위젯이 실제로 읽는 App Group 미러.
    static let appGroup = PremiumMirror(
        read: { SharedAppGroup.isPremium },
        write: { SharedAppGroup.isPremium = $0 },
        reloadWidgets: { WidgetCenter.shared.reloadAllTimelines() }
    )
}

@MainActor
@Observable
final class PremiumStore {
    /// 현재 프리미엄 여부 — 구매/복원/갱신/만료 시 자동 갱신. 게이트가 이 값을 읽는다.
    /// 조회가 신뢰 불가면 직전 값을 유지한다(켜기 게이트는 fail-closed 초기값 false로 안전).
    private(set) var isPremium: Bool = false
    /// **확정** 판정 — 값이 있으면 마지막 조회가 신뢰 가능했다는 뜻. nil이면 판정 불가.
    /// 강등 정리·자동 복구(reconcile) 같은 파괴적/영속적 동작은 이 값이 있을 때만 실행한다.
    ///
    /// 확정될 때마다 App Group 미러에 그대로 흘린다(`didSet`) — 위젯은 StoreKit을 직접 못
    /// 보고 이 미러만 읽는다. 미러 쓰기를 RootView의 `onChange`(값 **변화**)에만 두면
    /// 판정이 바뀌지 않는 실행에서는 한 번도 안 쓰이고, 기본값 false 탓에 유료 사용자에게
    /// 위젯 잠금이 뜬다(앱은 유료인데 위젯만 잠김). 변화가 아니라 확정이 쓰기 조건이다.
    private(set) var confirmedIsPremium: Bool? {
        didSet {
            // nil(판정 불가)이면 직전 확정값을 남긴다 — 일시적 조회 실패로 강등 금지.
            guard let confirmedIsPremium else { return }
            // 미러가 실제로 틀렸을 때만 쓰고 위젯을 다시 그린다. 판정이 그대로인 실행에서도
            // 여기까지는 오지만, 값이 같으면 리로드는 위젯 예산만 태운다.
            guard mirror.read() != confirmedIsPremium else { return }
            mirror.write(confirmedIsPremium)
            // 미러가 바뀌었으면 위젯이 낡은 잠금 상태를 들고 있다 — 판정 자체는 안 바뀐
            // 실행(재설치 후 첫 확정 등)이라 RootView의 onChange는 안 돌 수 있어 여기서 민다.
            mirror.reloadWidgets()
        }
    }
    /// 페이월에 표시할 상품(가격) 목록.
    private(set) var products: [PurchasableProduct] = []

    private let service: any PurchaseService
    private let analytics: any AnalyticsService
    private let mirror: PremiumMirror
    private var updatesTask: Task<Void, Never>?

    /// 저장 프로퍼티만 세팅하므로 nonisolated — Environment `@Entry` 기본값 등 비격리 컨텍스트에서도
    /// 생성 가능하게 한다(엔타이틀먼트 로드는 `start()`에서 main actor로 수행).
    nonisolated init(
        service: any PurchaseService,
        analytics: any AnalyticsService = DisabledAnalyticsService(),
        mirror: PremiumMirror = .appGroup
    ) {
        self.service = service
        self.analytics = analytics
        self.mirror = mirror
    }

    /// 프리뷰·테스트 편의 — 비동기 로드 없이 초기 프리미엄 상태를 즉시 세팅한다.
    ///
    /// `confirmedIsPremium`은 건드리지 않는다 — convenience init은 `self.init` 이후라
    /// `didSet`이 돌고, 프리뷰·테스트가 실기기의 App Group 미러를 덮어써 위젯 잠금 상태를
    /// 오염시킨다. 프리뷰가 필요한 건 게이트가 읽는 `isPremium`뿐이다.
    convenience init(previewIsPremium: Bool) {
        self.init(service: DisabledPurchaseService())
        self.isPremium = previewIsPremium
    }

    /// 앱 시작 시 1회 — 상품 로드 + 현재 엔타이틀먼트 반영 + 변경 스트림 구독.
    func start() async {
        products = await service.loadProducts()
        // 서비스는 로드 실패 시 빈 배열 폴백 — 페이월이 placeholder 가격으로 뜨는 상황을 기록한다.
        if products.isEmpty {
            analytics.log(.productsLoadFailed)
        }
        await refresh()
        updatesTask = Task { [weak self] in
            guard let stream = self?.service.entitlementUpdates() else { return }
            for await ids in stream {
                guard let self else { return }
                let premium = PremiumEntitlement.isPremium(entitledProductIDs: ids)
                // 갱신·환불 스트림은 같은 판정을 반복 방출할 수 있다 — 실제 변화만 기록.
                if premium != self.isPremium {
                    self.analytics.log(.entitlementChanged(premium: premium))
                }
                self.isPremium = premium
                // 스트림은 검증된 스냅샷만 방출한다(서비스가 nil을 거른다) — 확정 판정.
                self.confirmedIsPremium = premium
            }
        }
    }

    /// 현재 보유 엔타이틀먼트로 프리미엄 상태를 다시 계산한다.
    /// 페이월 진입 시 상품·트라이얼 자격 재확인 — 자격은 세션 중에도 변한다(타 기기에서
    /// 체험 소진, 계정 전환). 실패(빈 배열 폴백)면 기존 캐시를 유지해 CTA가 통째로
    /// 사라지는 깜빡임을 막는다.
    func reloadProducts() async {
        let latest = await service.loadProducts()
        guard !latest.isEmpty else { return }
        products = latest
    }

    func refresh() async {
        // nil = 조회 신뢰 불가 — 판정을 바꾸지 않는다(일시 실패로 유료 사용자를 강등 금지).
        guard let ids = await service.currentEntitlements() else {
            confirmedIsPremium = nil
            return
        }
        let premium = PremiumEntitlement.isPremium(entitledProductIDs: ids)
        isPremium = premium
        confirmedIsPremium = premium
    }

    /// 구매 시도 — 성공 시 즉시 엔타이틀먼트를 재확인해 잠금을 푼다.
    @discardableResult
    func purchase(_ productID: String) async -> PurchaseOutcome {
        let outcome = (try? await service.purchase(productID: productID)) ?? .userCancelled
        if outcome == .success { await refresh() }
        return outcome
    }

    /// 이전 구매 복원 — 복원 후 프리미엄 확인 여부를 결과로 기록한다.
    func restore() async {
        await service.restore()
        await refresh()
        analytics.log(.restoreResult(outcome: isPremium ? "success" : "failure"))
    }

    /// 특정 상품의 가격 표시 문자열(로드된 경우).
    func displayPrice(for product: PremiumProduct) -> String? {
        products.first { $0.id == product.id }?.displayPrice
    }

    /// 특정 상품에 표시할 무료 체험 일수 — 트라이얼이 있고 자격도 있을 때만. 판정은 Domain에 위임.
    func trialDays(for product: PremiumProduct) -> Int? {
        PaywallTrial.displayDays(for: product.id, in: products)
    }
    // 앱 수명 동안 사는 단일 인스턴스라 별도 deinit 취소는 두지 않는다(프로세스 종료 시 함께 정리).
}

extension EnvironmentValues {
    /// 기본값은 no-op 서비스 기반 — 프리뷰가 StoreKit 없이 동작한다(항상 비프리미엄).
    @Entry var premiumStore: PremiumStore = PremiumStore(service: DisabledPurchaseService())
}
