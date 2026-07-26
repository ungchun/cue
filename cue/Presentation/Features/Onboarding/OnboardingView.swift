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

    @FocusState private var isTextFieldFocused: Bool

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
    }

    // MARK: - 1장. 신호 — 점이 켜진다

    private var signalPage: some View {
        pageLayout {
            signalDot(coreDiameter: Spacing.smd, rippleDiameter: 88)
        } copy: {
            VStack(spacing: Spacing.smd) {
                // 브랜드 슬로건 — 설정 푸터와 같은 문구("잊지 않게, 흔들리지 않게").
                Text("Never forget, never waver")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("One quiet signal for the one thing you must not forget.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
            }
        }
    }

    /// 공통 페이지 골격 — 위 비주얼 존(고정 높이, 중앙 정렬)과 아래 안내 문구 존
    /// (고정 높이, 상단 정렬)을 모든 장이 공유해 **문구 시작 위치가 세 장에서 같다**.
    private func pageLayout(
        @ViewBuilder visual: () -> some View,
        @ViewBuilder copy: () -> some View
    ) -> some View {
        VStack(spacing: Spacing.zero) {
            Spacer(minLength: Spacing.zero)
            visual()
                .frame(height: 340)
            copy()
                // 비주얼(카드 스택이 존을 꽉 채우는 2장)과 문구 사이 숨 쉴 간격 —
                // 존 안쪽 패딩이라 세 장의 문구 시작 위치는 여전히 같다.
                .padding(.top, Spacing.lg)
                .padding(.horizontal, Spacing.xl)
                .frame(height: 150, alignment: .top)
            Spacer(minLength: Spacing.zero)
        }
    }

    // MARK: - 2장. 실물 카드 — 점이 카드가 된다

    private var cardPage: some View {
        pageLayout {
            // 실물 크기의 LA 카드 스택 — 뒤에 옅은 에코 링으로 1장의 점과 같은 존재임을 잇는다.
            ZStack {
                BreathingRings(base: 240, step: 100, opacities: [0.10, 0.06, 0.03])
                liveCardMock
            }
        } copy: {
            VStack(spacing: Spacing.smd) {
                Text("It stays, quietly.")
                    .font(.title2.weight(.semibold))
                Text("On your Lock Screen. Not a notification — it never slides away.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
            }
        }
    }

    /// LA 카드 실물 재현 — 메모(실제 문구)·일정·할일(스켈레톤) 세 카드를 잠금화면처럼
    /// 쌓는다. 일정·할일은 진짜 텍스트 대신 자리 표시 막대 — 내용이 아니라 형태를 보여준다.
    private var liveCardMock: some View {
        VStack(spacing: Spacing.smd) {
            Text(Date.now, format: .dateTime.hour().minute())
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(.tertiary)
            // 메모 — 큰 텍스트 카드(첫 큐 예시만 실제 문구)
            Text("Pick up milk")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(mockCardBackground)
            // 일정 — 왼쪽 실제 월간 캘린더("캘린더 함께 보기" 레이아웃) + 스켈레톤 이벤트 행
            HStack(spacing: Spacing.smd) {
                miniMonthCalendar
                Divider()
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    skeletonEventRow(titleWidth: 76, timeWidth: 52)
                    skeletonEventRow(titleWidth: 60, timeWidth: 44)
                    skeletonEventRow(titleWidth: 84, timeWidth: 48)
                }
                Spacer(minLength: Spacing.zero)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.smd)
            .background(mockCardBackground)
            // 할일 — 체크 동그라미 + 스켈레톤 막대(무채색)
            VStack(alignment: .leading, spacing: Spacing.sm) {
                skeletonTaskRow(barWidth: 96)
                skeletonTaskRow(barWidth: 64)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.smd)
            .background(mockCardBackground)
        }
        .frame(maxWidth: 280)
        .accessibilityHidden(true)
    }

    private var mockCardBackground: some View {
        RoundedRectangle(cornerRadius: Spacing.md)
            .fill(.regularMaterial)
            .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }

    /// 미니 월간 캘린더 — 이번 달을 실제로 그린다(공유 `MonthCalendarGrid` 재사용,
    /// 위젯 캘린더의 축소판). 일=빨강·토=옅게, 오늘은 채운 원으로 반전 강조.
    private var miniMonthCalendar: some View {
        let grid = MonthCalendarGrid(now: .now, monthOffset: 0)
        return VStack(spacing: Spacing.xxs) {
            HStack(spacing: Spacing.zero) {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { column, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(weekdayColor(grid: grid, column: column).opacity(0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: Spacing.zero) {
                    ForEach(Array(week.enumerated()), id: \.offset) { column, day in
                        miniDayCell(grid: grid, day: day, column: column)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(width: 132)
    }

    @ViewBuilder
    private func miniDayCell(grid: MonthCalendarGrid, day: Int?, column: Int) -> some View {
        if let day {
            Text("\(day)")
                .font(.caption2.weight(grid.isToday(day: day) ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(
                    grid.isToday(day: day)
                        ? AnyShapeStyle(Color(.systemBackground))
                        : AnyShapeStyle(weekdayColor(grid: grid, column: column))
                )
                .background {
                    if grid.isToday(day: day) {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 16, height: 16)
                    }
                }
        } else {
            Text(verbatim: " ").font(.caption2)
        }
    }

    /// 요일 색 — 일=빨강, 토=옅게, 평일=기본(위젯 캘린더와 같은 규칙).
    private func weekdayColor(grid: MonthCalendarGrid, column: Int) -> Color {
        let weekday = grid.weekdayIndex(column: column)
        if weekday == 1 { return .red }
        if weekday == 7 { return .secondary }
        return .primary
    }

    /// 일정 행 스켈레톤 — 색 막대 + 제목·시간 자리 막대(무채색 — 형태만 보여준다).
    private func skeletonEventRow(titleWidth: CGFloat, timeWidth: CGFloat) -> some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1.25)
                .fill(Color.secondary.opacity(0.6))
                .frame(width: 2.5, height: 20)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: titleWidth, height: 6)
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: timeWidth, height: 5)
            }
        }
    }

    /// 할일 행 스켈레톤 — 체크 동그라미 + 제목 자리 막대(무채색).
    private func skeletonTaskRow(barWidth: CGFloat) -> some View {
        HStack(spacing: Spacing.sm) {
            Circle()
                .strokeBorder(Color.secondary.opacity(0.6), lineWidth: 1.5)
                .frame(width: 16, height: 16)
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: barWidth, height: 6)
        }
    }

    // MARK: - 3장. 첫 큐 — 점이 당신의 큐가 된다

    /// 3장은 공통 골격을 쓰지 않는다 — 질문·입력을 세로 중앙에 두고, 키보드가 올라오면
    /// safe area가 줄며 중앙이 자연스럽게 위로 밀린다(키보드 회피는 시스템에 맡김).
    private var firstCuePage: some View {
        VStack(spacing: Spacing.zero) {
            Spacer(minLength: Spacing.zero)
            if viewModel.published {
                Text("Lock your phone and see it sitting on the Lock Screen.")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(Spacing.xxs)
                    .padding(.horizontal, Spacing.xl)
            } else {
                VStack(spacing: Spacing.lg) {
                    // 질문이 곧 제목 — 별도 타이틀 없이 바로 입력으로.
                    Text("What must you not forget right now?")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    VStack(spacing: Spacing.sm) {
                        TextField("Write it here", text: $viewModel.text, axis: .vertical)
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
                }
                .padding(.horizontal, Spacing.xl)
            }
            Spacer(minLength: Spacing.zero)
        }
        // 배경 탭 → 키보드 내림(입력 필드 자체 탭은 필드가 우선 처리).
        .contentShape(Rectangle())
        .onTapGesture { isTextFieldFocused = false }
        // 3장 도착 시 바로 입력 포커스, 다른 장으로 넘어가면 키보드 내림.
        .onChange(of: viewModel.page) { _, page in
            if page == 2 {
                if !viewModel.published { isTextFieldFocused = true }
            } else {
                isTextFieldFocused = false
            }
        }
    }

    // MARK: - Signal Dot (브랜드 비주얼 코어 — 점 + 퍼지는 동심원)

    /// 점 + 바깥으로 퍼지는 물결 링(1·3장) — 링이 점에서 커지며 옅어지다 사라지는 루프.
    private func signalDot(coreDiameter: CGFloat, rippleDiameter: CGFloat) -> some View {
        ZStack {
            RippleRings(diameter: rippleDiameter)
            Circle()
                .fill(Color.primary)
                .frame(width: coreDiameter, height: coreDiameter)
        }
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

/// 바깥으로 퍼지는 물결 링 3겹 — 링이 점에서 커지며 옅어지다 사라지는 루프(1장).
/// `repeatForever` + 상태 토글 대신 **시간 기반(TimelineView)**으로 그린다 — 위상을
/// 현재 시각에서 계산하므로 TabView 페이지를 나갔다 돌아와도(onAppear 재발화·상태 잔존)
/// 항상 같은 리듬으로 돈다. Reduce Motion이면 정적 동심원.
private struct RippleRings: View {
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 링 하나가 점에서 태어나 사라지기까지 — 3링 × 1초 시차로 파동이 끊기지 않는다.
    private let period: Double = 3.0

    var body: some View {
        Group {
            if reduceMotion {
                // 모션 최소화 — 정적 동심원으로 대체.
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .strokeBorder(Color.primary.opacity([0.25, 0.15, 0.08][index]), lineWidth: 1)
                            .frame(width: diameter * (0.5 + CGFloat(index) * 0.5),
                                   height: diameter * (0.5 + CGFloat(index) * 0.5))
                    }
                }
            } else {
                TimelineView(.animation) { context in
                    ZStack {
                        ForEach(0..<3, id: \.self) { index in
                            let progress = rippleProgress(at: context.date, ring: index)
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.4), lineWidth: 1.5)
                                .frame(width: diameter, height: diameter)
                                // 시작 스케일은 가운데 점 뒤에 숨는 크기 — 점에서 배어나온다.
                                .scaleEffect(Self.rippleScale(progress))
                                .opacity(0.7 * (1.0 - progress))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0→1 진행도 — 링마다 1/3 주기씩 어긋난 위상. (뷰 빌더 밖 계산 — 타입 체커 부담 분리.)
    private func rippleProgress(at date: Date, ring index: Int) -> Double {
        let time: Double = date.timeIntervalSinceReferenceDate
        let raw: Double = time / period + Double(index) / 3.0
        return raw.truncatingRemainder(dividingBy: 1.0)
    }

    private static func rippleScale(_ progress: Double) -> Double {
        0.12 + (2.6 - 0.12) * progress
    }
}

/// 제자리에서 숨쉬는 동심원 3겹(2장 배경) — 설정 푸터·페이월 에코와 같은 느린 pulse.
/// RippleRings와 같은 이유로 시간 기반(사인 곡선)으로 그린다.
private struct BreathingRings: View {
    let base: CGFloat
    let step: CGFloat
    let opacities: [Double]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                staticRings(scales: [1, 1, 1])
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                    staticRings(scales: Self.breathingScales(at: context.date))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// easeInOut 3초 왕복 ≈ 사인 6초 주기, 링마다 0.3초 시차. (뷰 빌더 밖에서 계산해
    /// 표현식을 잘게 쪼갠다 — 인라인 수식은 타입 체커가 시간 안에 못 푼다.)
    private static func breathingScales(at date: Date) -> [Double] {
        let time: Double = date.timeIntervalSinceReferenceDate
        return (0..<3).map { (index: Int) -> Double in
            let phase: Double = (time - Double(index) * 0.3) * 2.0 * Double.pi / 6.0
            return 1.0 + 0.05 * (1.0 + sin(phase))
        }
    }

    private func staticRings(scales: [Double]) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.primary.opacity(opacities[index]), lineWidth: 1)
                    .frame(width: base + CGFloat(index) * step, height: base + CGFloat(index) * step)
                    .scaleEffect(scales[index])
            }
        }
    }
}

#Preview {
    OnboardingView(
        viewModel: OnboardingViewModel(dependencies: .preview),
        onFinished: {}
    )
}
