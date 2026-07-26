//
//  OnboardingView.swift
//  cue / Presentation
//

import SwiftUI

/// 첫 실행 온보딩 — 3장: 컨셉(Signal Dot) → 가치(잠금화면 목업) → 첫 큐 띄우기(인터랙티브).
///
/// 기능 나열 대신 **첫 큐를 실제로 띄우게 만드는 것**이 목적이다 — cue의 아하 모먼트는
/// 앱 안이 아니라 잠금화면에 있다. 다른 탭 기능 소개는 온보딩이 아니라 각 탭에서(점진적 공개).
/// 모든 장에서 스킵 가능. 권한 요청 없음(메모는 권한이 필요 없어 첫 액션으로 완벽).
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
                conceptPage.tag(0)
                valuePage.tag(1)
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
            // 게시까지 마쳤으면 스킵은 무의미 — 하단 Done만 남긴다.
            if !viewModel.published {
                Button("Skip") { finish() }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(Spacing.lg)
            }
        }
        .onAppear { echoPulsing = true }
    }

    // MARK: - 1장. 컨셉

    private var conceptPage: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            signalDot
                .padding(.bottom, Spacing.xl)
            Text(verbatim: "Cue your day.")
                .font(.title.weight(.semibold))
                .fontDesign(.rounded)
            Text("One thing you must not forget — right on your Lock Screen.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            Spacer()
        }
    }

    /// Signal Dot — 점 하나 + 퍼지는 동심원 3겹(브랜드 비주얼 코어). 설정 푸터 에코와 같은
    /// 숨쉬기 루프, Reduce Motion이면 정적. 순수 장식이라 접근성에서 제외.
    private var signalDot: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let diameter = 44 + CGFloat(index) * 44
                let opacities: [Double] = [0.25, 0.15, 0.08]
                Circle()
                    .strokeBorder(Color.primary.opacity(opacities[index]), lineWidth: 1)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(echoPulsing && !reduceMotion ? 1.12 : 1)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 3)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                        value: echoPulsing
                    )
            }
            Circle()
                .fill(Color.primary)
                .frame(width: Spacing.smd, height: Spacing.smd)
        }
        .frame(height: 132)
        .accessibilityHidden(true)
    }

    // MARK: - 2장. 가치 (잠금화면 목업)

    private var valuePage: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            lockScreenMockup
            Text("It stays, quietly.")
                .font(.title2.weight(.semibold))
                .padding(.top, Spacing.lg)
            Text("No need to open the app — and it never disappears like a notification.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            Spacer()
        }
    }

    /// 잠금화면 축소판 — 시계 + 메모 LA 카드 모양. 실제 위젯을 그리진 않고 분위기만 재현한다
    /// (시스템 재질·시스템 컬러만 사용).
    private var lockScreenMockup: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xxs) {
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.system(.largeTitle, design: .rounded).weight(.medium))
            }
            Text("Pick up milk")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Spacing.md)
                        .fill(.regularMaterial)
                )
        }
        .padding(Spacing.lg)
        .frame(maxWidth: 280)
        .background(
            RoundedRectangle(cornerRadius: Spacing.lg)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityHidden(true)
    }

    // MARK: - 3장. 첫 큐 띄우기

    private var firstCuePage: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            if viewModel.published {
                Image(systemName: "lock.iphone")
                    .font(.system(.largeTitle).weight(.light))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, Spacing.sm)
                Text("Your cue is live.")
                    .font(.title2.weight(.semibold))
                Text("Now lock your phone and see it on the Lock Screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            } else {
                Text("Try your first cue")
                    .font(.title2.weight(.semibold))
                VStack(spacing: Spacing.sm) {
                    TextField("What must you not forget right now?", text: $viewModel.text, axis: .vertical)
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
            }
            Spacer()
            Spacer()
        }
        // 3장에 도착하면 바로 입력 포커스 — 타이핑까지의 마찰을 없앤다.
        .onChange(of: viewModel.page) { _, page in
            if page == 2, !viewModel.published { isTextFieldFocused = true }
        }
    }

    // MARK: - 하단 주 버튼 (화면당 Primary 하나)

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.page < 2 {
            Button("Continue") {
                withAnimation { viewModel.page += 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
        } else if viewModel.published {
            Button("Done") { finish() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        } else {
            Button("Show on Lock Screen") {
                isTextFieldFocused = false
                Task { await viewModel.publish() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
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
