//
//  OnboardingView.swift
//  cue / Presentation
//

import SwiftUI

/// 첫 실행 온보딩 — 3장: 신호(Signal Dot) → 실물 카드 → 첫 큐 띄우기.
///
/// 일러스트·기능 나열 대신 cue의 브랜드 언어로 말한다: 무채색, 넉넉한 여백,
/// 타이포그래피 중심, 그리고 **Signal Dot이 3장을 관통하는 모티프**다 —
/// 1장에서 점이 켜지고, 2장에서 그 점이 실물 카드가 되고, 3장에서 사용자의
/// 첫 큐가 된다. 마지막 장은 설명이 아니라 실제 게시 — 아하 모먼트는 잠금화면에 있다.
/// 권한 요청 없음(메모는 권한이 필요 없어 첫 액션으로 완벽).
struct OnboardingView: View {
    // ⚠️ 임시 — 눈 검증용: true면 완주 여부와 무관하게 앱을 켤 때마다 온보딩을 띄운다.
    // 검증 끝나면 false로 바꾼다(완주 플래그 기반 1회 표시로 전환).
    static let alwaysShowsForReview = true

    @State var viewModel: OnboardingViewModel
    /// 완료·스킵 공통 마감 — RootView가 커버를 닫고 메모 탭을 새로고침한다.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isTextFieldFocused: Bool
    /// 에코 링 숨쉬기 트리거 — 설정 푸터·페이월 에코와 같은 느린 pulse 루프.
    @State private var echoPulsing = false

    var body: some View {
        VStack(spacing: Spacing.zero) {
            TabView(selection: $viewModel.page) {
                signalPage.tag(0)
                cardPage.tag(1)
                firstCuePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            bottomButton
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
        }
        .background(Color(.systemBackground))
        // 앱 전체와 동일한 무채색 틴트 — fullScreenCover는 루트의 .tint를 상속하지 않는다.
        .tint(.primary)
        .overlay(alignment: .topTrailing) {
            Button("Skip") { finish() }
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(Spacing.lg)
                .opacity(viewModel.published ? 0 : 1)
        }
        .onAppear { echoPulsing = true }
    }

    // MARK: - 1장. 신호 — 점이 켜진다

    private var signalPage: some View {
        VStack(spacing: Spacing.zero) {
            Spacer()
            signalDot(coreDiameter: Spacing.smd, rippleDiameter: 88)
                .frame(height: 180)
            Spacer()
            VStack(spacing: Spacing.smd) {
                Text(verbatim: "Cue your day.")
                    .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                Text("One quiet signal for the one thing you must not forget.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
            }
            .padding(.bottom, Spacing.xxl)
            Spacer()
        }
    }

    // MARK: - 2장. 실물 카드 — 점이 카드가 된다

    private var cardPage: some View {
        VStack(spacing: Spacing.zero) {
            Spacer()
            // 실물 크기의 메모 LA 카드 — 일러스트가 아니라 잠금화면에 뜨는 그 모습.
            // 뒤에 옅은 에코 링을 깔아 1장의 점과 같은 존재임을 잇는다.
            ZStack {
                echoRings(base: 200, step: 90, opacities: [0.10, 0.06, 0.03])
                liveCardMock
            }
            .frame(height: 260)
            Spacer()
            VStack(spacing: Spacing.smd) {
                Text("It stays, quietly.")
                    .font(.title2.weight(.semibold))
                Text("On your Lock Screen. Not a notification — it never slides away.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
            }
            .padding(.bottom, Spacing.xxl)
            Spacer()
        }
    }

    /// 메모 LA 카드 실물 재현 — 글래스 재질 + 큰 텍스트(위젯과 같은 인상). 위에 잠금화면
    /// 시계를 작게 얹어 "잠금화면 위"라는 맥락만 준다.
    private var liveCardMock: some View {
        VStack(spacing: Spacing.md) {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(.title, design: .rounded).weight(.medium))
                .foregroundStyle(.tertiary)
            Text("Pick up milk")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg + Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.lg)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 24, y: 8)
                )
                .padding(.horizontal, Spacing.xl + Spacing.sm)
        }
        .accessibilityHidden(true)
    }

    // MARK: - 3장. 첫 큐 — 점이 당신의 큐가 된다

    private var firstCuePage: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            if viewModel.published {
                signalDot(coreDiameter: Spacing.sm, rippleDiameter: 64)
                    .frame(height: 120)
                Text("Your cue is on.")
                    .font(.title2.weight(.semibold))
                Text("Lock your phone and see it sitting on the Lock Screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
            } else {
                Text("Light your first cue")
                    .font(.title2.weight(.semibold))
                Text("What must you not forget right now?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                VStack(spacing: Spacing.sm) {
                    TextField("Pick up milk", text: $viewModel.text, axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .focused($isTextFieldFocused)
                        .submitLabel(.done)
                    Rectangle()
                        .fill(viewModel.canPublish ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(height: 1)
                        .frame(maxWidth: 240)
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.top, Spacing.md)
            }
            Spacer()
            Spacer()
        }
        // 3장에 도착하면 바로 입력 포커스 — 타이핑까지의 마찰을 없앤다.
        .onChange(of: viewModel.page) { _, page in
            if page == 2, !viewModel.published { isTextFieldFocused = true }
        }
    }

    // MARK: - Signal Dot (브랜드 비주얼 코어 — 점 + 퍼지는 동심원)

    /// 점 + 바깥으로 퍼지는 물결 링(1·3장) — 링이 점에서 커지며 옅어지다 사라지는 루프라
    /// "신호가 퍼진다"가 눈에 보인다(숨쉬기 pulse보다 방향성이 분명). 링 3개를 시차로 돌려
    /// 파동이 끊기지 않는다. Reduce Motion이면 정적 동심원.
    private func signalDot(coreDiameter: CGFloat, rippleDiameter: CGFloat) -> some View {
        ZStack {
            if reduceMotion {
                echoRings(base: rippleDiameter * 0.5, step: rippleDiameter * 0.5,
                          opacities: [0.25, 0.15, 0.08])
            } else {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: rippleDiameter, height: rippleDiameter)
                        .scaleEffect(echoPulsing ? 2.6 : 0.3)
                        .opacity(echoPulsing ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 2.7)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.9),
                            value: echoPulsing
                        )
                }
            }
            Circle()
                .fill(Color.primary)
                .frame(width: coreDiameter, height: coreDiameter)
        }
        .accessibilityHidden(true)
    }

    /// 동심원 스트로크 링 3겹 — 링마다 시차를 둔 숨쉬기 루프. 순수 장식.
    private func echoRings(base: CGFloat, step: CGFloat, opacities: [Double]) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.primary.opacity(opacities[index]), lineWidth: 1)
                    .frame(width: base + CGFloat(index) * step, height: base + CGFloat(index) * step)
                    .scaleEffect(echoPulsing && !reduceMotion ? 1.1 : 1)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                        value: echoPulsing
                    )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - 하단 주 버튼 (화면당 Primary 하나)

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.page < 2 {
            Button { withAnimation { viewModel.page += 1 } } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    // tint(.primary) 캡슐은 다크에서 흰 배경 — 라벨을 배경 반전색으로(페이월 CTA 관용구).
                    .foregroundStyle(Color(.systemBackground))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if viewModel.published {
            Button { finish() } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    // tint(.primary) 캡슐은 다크에서 흰 배경 — 라벨을 배경 반전색으로(페이월 CTA 관용구).
                    .foregroundStyle(Color(.systemBackground))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                isTextFieldFocused = false
                Task { await viewModel.publish() }
            } label: {
                Text("Show on Lock Screen")
                    .frame(maxWidth: .infinity)
                    // tint(.primary) 캡슐은 다크에서 흰 배경 — 라벨을 배경 반전색으로(페이월 CTA 관용구).
                    .foregroundStyle(Color(.systemBackground))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canPublish)
        }
    }

    private func finish() {
        Task {
            await viewModel.finish()
            onFinished()
        }
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(dependencies: .preview),
        onFinished: {}
    )
}
