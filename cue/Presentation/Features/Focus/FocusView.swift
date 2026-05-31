//
//  FocusView.swift
//  cue / Presentation
//

import Combine
import SwiftUI
import UIKit

/// 집중 탭의 메인 화면 — 원형 ring + 시간이 **항상** 떠 있고, 진행 중이면 ring이 차오르고
/// 컨트롤(일시정지/스킵/종료)이 노출된다. 설정은 우상단 ⚙ 버튼이 띄우는 시트에서 잡는다.
///
/// 시작은 시트 안의 "시작" 버튼이 담당 — 시트를 닫으면서 부모(이 뷰)가 들고 있는
/// `viewModel.start()`를 호출해 같은 메인 뷰 안에서 세션이 시작된다(별도 풀스크린 뷰 없음).
struct FocusView: View {
    @Bindable var viewModel: FocusViewModel
    /// 시트 표시 — ⚙ 버튼이 true로 올린다.
    @State private var showingSettings = false

    /// 1초마다 publish — `tick`은 일시정지·완료·세션 없음 상태에 자체 가드.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 백그라운드 진입 시각 — 복귀 시 흘러간 만큼 한 번에 tick해 단계 종료 시점을 추격.
    /// 세션 없는 idle 상태에선 캡처하지 않는다(추격할 게 없음).
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            cycleIndicator
            Spacer()
            ringWithTime
            phaseLabel
            Spacer()
            controlRow
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("집중")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("설정")
                // 세션 진행 중엔 설정 변경 비활성 — 현재 세션의 길이·반복은 잠금.
                .disabled(viewModel.session != nil)
            }
        }
        .task { await viewModel.onAppear() }
        .sheet(isPresented: $showingSettings) {
            FocusSettingsSheet(settings: $viewModel.settings) {
                // 시트 닫고 메인에서 세션 시작.
                showingSettings = false
                viewModel.start()
            }
        }
        .onReceive(ticker) { _ in
            viewModel.session?.tick(seconds: 1)
        }
        .onChange(of: viewModel.session?.phase) { _, newPhase in
            // 단계 전환(집중 ↔ 휴식)마다 success 햅틱. nil → non-nil(세션 시작) 변화도
            // 트리거되지만 시작 자체는 success를 알리는 신호로 자연스럽다.
            guard newPhase != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .onChange(of: viewModel.session?.isComplete) { _, completed in
            // 마지막 집중 종료 또는 abort()로 완료되면 자동으로 세션을 정리해 idle로 복귀.
            if completed == true {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                viewModel.stopSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                if backgroundedAt == nil, viewModel.session != nil {
                    backgroundedAt = Date()
                }
            case .active:
                if let date = backgroundedAt {
                    let elapsed = Date().timeIntervalSince(date)
                    if elapsed > 0 { viewModel.session?.tick(seconds: elapsed) }
                    backgroundedAt = nil
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - 상단 사이클 진행

    /// "1 / 4" — idle이거나 1 사이클짜리 세션엔 의미가 없어 빈 자리(`Color.clear`)로 둔다.
    /// 자리를 유지해야 idle ↔ running 전환에서 ring 위치가 흔들리지 않는다.
    @ViewBuilder
    private var cycleIndicator: some View {
        if let session = viewModel.session, session.totalCycles > 1 {
            Text("\(session.currentCycle) / \(session.totalCycles)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Color.clear.frame(height: Spacing.md)
        }
    }

    // MARK: - 가운데 ring + 시간

    /// 원형 ring + 한가운데 mm:ss. idle엔 외곽 회색 ring만, running엔 그 위에 tint progress
    /// 트림이 덧그려져 시계 방향으로 차오른다.
    private var ringWithTime: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            if viewModel.session != nil {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    // 12시 방향 시작 → 시계 방향으로 채워지도록 회전.
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            }
            Text(timeText)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, Spacing.xl)
    }

    /// ring 아래 단계 라벨 — idle이면 빈 자리, running이면 "집중 중" / "휴식 중".
    @ViewBuilder
    private var phaseLabel: some View {
        if let session = viewModel.session {
            Text(session.phase == .focus ? "집중 중" : "휴식 중")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else {
            // idle 시 자리만 유지 — ring 위치가 흔들리지 않게.
            Color.clear.frame(height: Spacing.lg)
        }
    }

    // MARK: - 하단 컨트롤

    /// 일시정지/재개 · 스킵 · 종료 — running에만 노출. idle엔 자리만 유지.
    @ViewBuilder
    private var controlRow: some View {
        if let session = viewModel.session {
            HStack(spacing: Spacing.xl) {
                controlButton(
                    systemImage: session.isPaused ? "play.fill" : "pause.fill",
                    label: session.isPaused ? "재개" : "일시정지"
                ) {
                    session.isPaused ? session.resume() : session.pause()
                }

                controlButton(systemImage: "forward.end.fill", label: "스킵") {
                    session.skip()
                }

                controlButton(
                    systemImage: "xmark",
                    label: "종료",
                    tint: .red
                ) {
                    viewModel.stopSession()
                }
            }
        } else {
            // idle — 자리만 유지해 ring이 같은 위치에 머문다.
            Color.clear.frame(height: Spacing.xxl + Spacing.md)
        }
    }

    /// 컨트롤 단일 버튼 — 원형 배경 + 아이콘 + 라벨.
    @ViewBuilder
    private func controlButton(
        systemImage: String,
        label: String,
        tint: Color = .accentColor,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: Spacing.xxl, height: Spacing.xxl)
                    .background(Circle().fill(tint.opacity(0.15)))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - 계산값

    /// running 시 0(시작) → 1(단계 종료)로 차오르는 비율. idle이면 0(트림이 안 그려짐).
    private var progress: Double {
        guard let session = viewModel.session else { return 0 }
        let total = session.phaseDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - session.remaining / total))
    }

    /// "mm:ss". running이면 남은 시간, idle이면 설정된 집중 시간을 보여준다.
    private var timeText: String {
        let seconds = viewModel.session?.remaining ?? viewModel.settings.focusDuration
        return Duration.seconds(max(0, seconds))
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    NavigationStack {
        FocusView(viewModel: FocusViewModel(dependencies: .preview))
    }
}
