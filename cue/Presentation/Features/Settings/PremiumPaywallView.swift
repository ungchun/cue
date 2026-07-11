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
    }

    @State private var selectedPlan: Plan = .yearly

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

    // MARK: - 히어로

    /// 설정 배너와 같은 물결 에코 카드 — 타이틀 + 큐 사인 슬로건.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Cue Premium")
                .font(.largeTitle.weight(.bold))
            Text("잊지 않게, 흔들리지 않게")
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
                title: "무제한 라이브",
                detail: "하루 2회 제한 없이 켜고 새로고침"
            )
            featureRow(
                icon: "clock.arrow.2.circlepath",
                title: "라이브 항상 표시",
                detail: "하루 종일 꺼지지 않는 라이브"
            )
            featureRow(
                icon: "calendar",
                title: "캘린더 함께 보기",
                detail: "메모·일정 옆에 월간 캘린더"
            )
            featureRow(
                icon: "paintpalette",
                title: "라이브 커스텀",
                detail: "배경·글자 색을 내 취향대로"
            )
            featureRow(
                icon: "timer",
                title: "집중 세션 무제한",
                detail: "뽀모도로 세션을 원하는 만큼"
            )
            featureRow(
                icon: "plus.circle",
                title: "계속 추가될 기능",
                detail: "프리미엄 기능은 계속 늘어나요"
            )
        }
        .padding(.vertical, Spacing.sm)
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
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
            planCard(.monthly, title: "월간", price: "₩2,900", unit: "/ 월", badge: nil)
            planCard(.yearly, title: "연간", price: "₩19,000", unit: "/ 년", badge: "45% 절약")
            planCard(.lifetime, title: "평생", price: "₩44,000", unit: "한 번 결제", badge: nil)
        }
    }

    /// 플랜 라디오 카드 — 선택 시 테두리 강조. 가격은 StoreKit 연결 전 placeholder.
    private func planCard(_ plan: Plan, title: String, price: String, unit: String, badge: String?) -> some View {
        Button {
            selectedPlan = plan
        } label: {
            HStack {
                Text(title)
                    .font(.body.weight(.semibold))
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
            Button("구독 복원") {}
                .font(.caption2)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .padding(.bottom, Spacing.sm)

            HStack(spacing: Spacing.md) {
                Button("이용약관") {}
                Button("개인정보처리방침") {}
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)

            Button {
                // TODO: StoreKit 결제 연결.
            } label: {
                Text("Premium 시작하기")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .tint(.primary)

            Text("자동 갱신 · 언제든 취소 가능")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.md)
    }
}

#Preview {
    PremiumPaywallView()
}
