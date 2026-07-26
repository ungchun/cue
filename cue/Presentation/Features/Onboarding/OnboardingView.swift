//
//  OnboardingView.swift
//  cue / Presentation
//

import SwiftUI

/// 첫 실행 온보딩 — 3장: 히어로(잠금화면 일러스트 + 핵심 가치) → 기능 소개 → 첫 큐 띄우기.
///
/// 애플식 온보딩 문법을 따른다: 상단 히어로 일러스트 + 큰 볼드 타이틀 + 아이콘 행,
/// 우상단 ✕ 닫기, 하단 주 버튼 하나. 마지막 장은 설명이 아니라 **첫 큐를 실제로
/// 띄우게 만드는 것**이 목적 — cue의 아하 모먼트는 앱 안이 아니라 잠금화면에 있다.
/// 권한 요청 없음(메모는 권한이 필요 없어 첫 액션으로 완벽).
struct OnboardingView: View {
    // ⚠️ 임시 — 눈 검증용: true면 완주 여부와 무관하게 앱을 켤 때마다 온보딩을 띄운다.
    // 검증 끝나면 false로 바꾼다(완주 플래그 기반 1회 표시로 전환).
    static let alwaysShowsForReview = true

    @State var viewModel: OnboardingViewModel
    /// 완료·스킵 공통 마감 — RootView가 커버를 닫고 메모 탭을 새로고침한다.
    let onFinished: () -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: Spacing.zero) {
            TabView(selection: $viewModel.page) {
                heroPage.tag(0)
                featuresPage.tag(1)
                firstCuePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .ignoresSafeArea(edges: .top)

            bottomButton
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.md)
        }
        .background(Color(.systemBackground))
        // 앱 전체와 동일한 무채색 틴트 — fullScreenCover는 루트의 .tint를 상속하지 않는다.
        .tint(.primary)
        .overlay(alignment: .topTrailing) { closeButton }
    }

    /// 우상단 ✕ — 어느 장에서든 온보딩을 닫는다(레퍼런스 온보딩들의 공통 문법).
    private var closeButton: some View {
        Button { finish() } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(Spacing.smd)
                .background(Circle().fill(.thinMaterial))
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.md)
        .accessibilityLabel(Text("Skip"))
    }

    // MARK: - 1장. 히어로 — 잠금화면 일러스트 + 핵심 가치

    private var heroPage: some View {
        VStack(spacing: Spacing.zero) {
            heroIllustration
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Keep one thing in sight.")
                    .font(.title.weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.top, Spacing.xl)
                featureRow(
                    icon: "sparkles.rectangle.stack",
                    title: "Lives on your Lock Screen",
                    description: "Your cue stays visible — no need to open the app."
                )
                featureRow(
                    icon: "bell.slash",
                    title: "Not a notification",
                    description: "It doesn't ring, and it never slides away."
                )
                featureRow(
                    icon: "hand.tap",
                    title: "One tap to put it up",
                    description: "Write one line and pin it. That's all."
                )
                Spacer(minLength: Spacing.zero)
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    /// 히어로 일러스트 — 그라데이션 배경 위 미니 잠금화면(시계 + 색 캡슐 카드).
    /// 실제 위젯을 그리진 않고 분위기만 재현한다(시스템 컬러 조합의 그라데이션).
    private var heroIllustration: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: Spacing.md) {
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.system(.largeTitle, design: .rounded).weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                mockCard(fill: Color.red, lines: 2)
                mockCard(fill: Color.black.opacity(0.75), lines: 2)
                mockCard(fill: Color.white.opacity(0.85), lines: 1)
            }
            .padding(Spacing.lg)
            .frame(width: 220)
            .background(
                RoundedRectangle(cornerRadius: Spacing.lg + Spacing.sm)
                    .fill(.white.opacity(0.14))
            )
            .padding(.top, Spacing.xxl)
        }
        .frame(height: 380)
        .clipShape(
            .rect(bottomLeadingRadius: Spacing.xl, bottomTrailingRadius: Spacing.xl)
        )
        .accessibilityHidden(true)
    }

    /// 히어로 안 LA 카드 축소판 — 색 배경 + 텍스트 자리 표시 줄.
    private func mockCard(fill: Color, lines: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(0..<lines, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == 0 ? 0.7 : 0.45))
                    .frame(width: index == 0 ? 88 : 132, height: Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(RoundedRectangle(cornerRadius: Spacing.md).fill(fill))
    }

    // MARK: - 2장. 기능 소개 (애플식 — 큰 좌측 타이틀 + 아이콘 행)

    private var featuresPage: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Spacer()
            Text("One app,\nfour signals.")
                .font(.largeTitle.weight(.bold))
                .padding(.bottom, Spacing.lg)
            featureRow(
                icon: "note.text",
                title: "Memo",
                description: "Pin one note in large type."
            )
            featureRow(
                icon: "calendar",
                title: "Schedule",
                description: "Today's events, packed onto the Lock Screen."
            )
            featureRow(
                icon: "checklist",
                title: "Tasks",
                description: "Check off reminders without unlocking."
            )
            featureRow(
                icon: "timer",
                title: "Focus",
                description: "A Pomodoro that stays in sight."
            )
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    /// 아이콘 + 제목 + 설명 행 — 레퍼런스 온보딩들의 공통 행 문법.
    private func featureRow(
        icon: String, title: LocalizedStringKey, description: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title2.weight(.regular))
                .foregroundStyle(.secondary)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.zero)
        }
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
                    .font(.title.weight(.bold))
                Text("Now lock your phone and see it on the Lock Screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            } else {
                Text("Try your first cue")
                    .font(.title.weight(.bold))
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

    // MARK: - 하단 주 버튼 (화면당 Primary 하나)

    @ViewBuilder
    private var bottomButton: some View {
        if viewModel.page < 2 {
            Button { withAnimation { viewModel.page += 1 } } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if viewModel.published {
            Button { finish() } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                isTextFieldFocused = false
                Task { await viewModel.publish() }
            } label: {
                Text("Show on Lock Screen").frame(maxWidth: .infinity)
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
