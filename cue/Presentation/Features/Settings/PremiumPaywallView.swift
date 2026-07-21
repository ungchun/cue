//
//  PremiumPaywallView.swift
//  cue / Presentation
//
//  Cue Premium 페이월 시트 — 가격(플랜) → 가치(기능) → 행동(CTA) 순서.
//  히어로는 설정 배너와 같은 물결 에코를 재사용해 배너→페이월이 한 브랜드 문법으로 이어진다.
//  결제(StoreKit) 연결은 추후 — 지금은 UI + 플랜 선택 상태까지. 가격은 placeholder.
//

import SwiftUI

struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss

    /// 구매 플랜. 연간이 기본 선택(절약 뱃지) — 업계 표준 앵커.
    enum Plan: CaseIterable {
        case monthly
        case yearly
        case lifetime

        /// 대응 StoreKit 상품 — 구매·가격 조회 키.
        var product: PremiumProduct {
            switch self {
            case .monthly: return .monthly
            case .yearly: return .yearly
            case .lifetime: return .lifetime
            }
        }
    }

    @State private var selectedPlan: Plan = .yearly
    @State private var echoAppeared = false
    @State private var echoPulsing = false
    @State private var purchasing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(\.premiumStore) private var premiumStore

    private let termsURL = URL(string: "https://ungchun.github.io/cue-legal/terms.html")!
    private let privacyURL = URL(string: "https://ungchun.github.io/cue-legal/privacy.html")!

    var body: some View {
        VStack(spacing: Spacing.zero) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    hero
                    plans
                    features
                }
                .padding(Spacing.md)
            }
            footer
        }
        .background(alignment: .topLeading) { echo }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(Spacing.sm)
                    .background(Circle().fill(.thinMaterial))
            }
            .buttonStyle(.plain)
            .padding(Spacing.md)
        }
        .presentationDetents([.large])
    }

    // MARK: - 에코 장식

    /// 히어로 뒤 방사 에코 — 타이틀 좌상단 밖을 진원지로 동심원이 퍼진다.
    /// 배너의 물결 겹 문법을 "신호가 퍼지는" 방사형으로 확대한 순수 장식.
    /// 등장 시 한 번 확산 페이드인 후, 링마다 시차를 둔 느린 숨쉬기 루프로
    /// 물결이 은은하게 전파되는 느낌을 유지한다. Reduce Motion이면 정적 표시.
    private var echo: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<8, id: \.self) { index in
                let diameter = 180 + CGFloat(index) * 120
                // 면 채움 — 링이 겹칠수록 진원지가 진해진다(배너의 겹 문법).
                let opacities: [Double] = [0.10, 0.05, 0.04, 0.03, 0.025, 0.02, 0.015, 0.012]
                Circle()
                    .fill(Color.primary.opacity(opacities[index]))
                    .frame(width: diameter, height: diameter)
                    .offset(x: -diameter / 2 - 40, y: -diameter / 2 - 20)
                    .scaleEffect(
                        echoPulsing && !reduceMotion ? 1.05 : 1,
                        anchor: .topLeading
                    )
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 4)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.35),
                        value: echoPulsing
                    )
                    .scaleEffect(
                        echoAppeared || reduceMotion ? 1 : 0.85,
                        anchor: .topLeading
                    )
                    .opacity(echoAppeared || reduceMotion ? 1 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeOut(duration: 0.7).delay(Double(index) * 0.06),
                        value: echoAppeared
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            echoAppeared = true
            echoPulsing = true
        }
    }

    // MARK: - 히어로

    /// 설정 배너와 같은 물결 에코 카드 — 타이틀 + 큐 사인 슬로건.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Cue Premium")
                .font(.largeTitle.weight(.bold))
            Text("Never forget, never waver")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.xl)
    }

    // MARK: - 기능

    private var features: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            featureRow(
                icon: "infinity",
                title: "Unlimited Live",
                detail: "Turn on and refresh without the 2-per-day limit"
            )
            featureRow(
                icon: "clock.arrow.2.circlepath",
                title: "Always Show Live",
                detail: "A Live that stays on all day"
            )
            featureRow(
                icon: "calendar",
                title: "Show Calendar",
                detail: "A monthly calendar beside your memos, schedule, and to-dos"
            )
            featureRow(
                icon: "paintpalette",
                title: "Customize Live",
                detail: "Background and text colors your way"
            )
            featureRow(
                icon: "timer",
                title: "Unlimited Focus Sessions",
                detail: "As many Pomodoro sessions as you want"
            )
            featureRow(
                icon: "plus.circle",
                title: "More Features Coming",
                detail: "Premium features keep growing"
            )
        }
        .padding(.vertical, Spacing.sm)
    }

    private func featureRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .center, spacing: Spacing.smd) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .frame(width: Spacing.lg)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 플랜

    private var plans: some View {
        VStack(spacing: Spacing.sm) {
            // 가격은 StoreKit에서 로드된 로케일 가격을 우선 사용, 미로드 시 폴백 문자열.
            planCard(.monthly, title: "Monthly",
                     price: premiumStore.displayPrice(for: .monthly) ?? "₩2,900", unit: "/ mo", badge: nil)
            planCard(.yearly, title: "Yearly",
                     price: premiumStore.displayPrice(for: .yearly) ?? "₩19,000", unit: "/ yr", badge: "Save 45%")
            planCard(.lifetime, title: "Lifetime",
                     price: premiumStore.displayPrice(for: .lifetime) ?? "₩44,000", unit: "one-time", badge: nil)
        }
    }

    /// 플랜 라디오 카드 — 선택 시 테두리 강조. 가격은 StoreKit 연결 전 placeholder.
    private func planCard(_ plan: Plan, title: LocalizedStringKey, price: String, unit: LocalizedStringKey, badge: LocalizedStringKey?) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Text(price)
                    .font(.body.weight(.bold))
                    .monospacedDigit()
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                    .fill(selectedPlan == plan ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.md, style: .continuous)
                    .strokeBorder(
                        selectedPlan == plan ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary),
                        lineWidth: selectedPlan == plan ? 2 : 1
                    )
            )
            // 절약 뱃지 — 카드 우상단에 걸침.
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(Capsule().fill(.primary))
                        .offset(y: -Spacing.sm)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var footer: some View {
        VStack(spacing: Spacing.sm) {
            Button {
                Task { await startPurchase() }
            } label: {
                Group {
                    if purchasing {
                        ProgressView().tint(Color(.systemBackground))
                    } else {
                        Text("Start Premium")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color(.systemBackground))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .disabled(purchasing)

            Text("Auto-renewable · Cancel anytime")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.sm)

            HStack(spacing: Spacing.sm) {
                Button("Restore") { Task { await restore() } }
                Text("·")
                Button("Terms of Use") { openURL(termsURL) }
                Text("·")
                Button("Privacy Policy") { openURL(privacyURL) }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - 구매 · 복원

    /// 선택 플랜을 구매한다. 성공(또는 이미 프리미엄)이면 페이월을 닫는다.
    private func startPurchase() async {
        purchasing = true
        defer { purchasing = false }
        let outcome = await premiumStore.purchase(selectedPlan.product.id)
        if outcome == .success || premiumStore.isPremium { dismiss() }
    }

    /// 이전 구매를 복원한다. 프리미엄이 확인되면 페이월을 닫는다.
    private func restore() async {
        await premiumStore.restore()
        if premiumStore.isPremium { dismiss() }
    }
}

#Preview {
    PremiumPaywallView()
}
