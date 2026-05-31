//
//  FocusView.swift
//  cue / Presentation
//

import Combine
import SwiftUI
import UIKit

/// 집중 탭의 메인 화면 — 원형 ring + 시간이 **항상** 떠 있고, 상단엔 선택된 세션의
/// 타이틀(있을 때만), idle 상태엔 시작 버튼·running 상태엔 일시정지/스킵/종료 컨트롤.
///
/// 우상단 버튼이 세션 목록 시트(`FocusSessionsListSheet`)를 띄우고, 그 시트 위에 다시
/// 중간 detent 시트(`FocusSessionEditorSheet`)가 추가/수정 진입점이 된다. 행 탭으로 세션을
/// 고르면 시트가 닫히고 메인 화면이 그 세션의 타이틀·설정을 즉시 반영한다.
struct FocusView: View {
    @Bindable var viewModel: FocusViewModel
    /// 세션 목록 시트 표시 — 우상단 버튼이 true로 올린다.
    @State private var showingSessions = false

    /// 1초마다 publish — `tick`은 일시정지·완료·세션 없음 상태에 자체 가드.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 백그라운드 진입 시각 — 복귀 시 흘러간 만큼 한 번에 tick해 단계 종료 시점을 추격.
    /// 세션 없는 idle 상태에선 캡처하지 않는다.
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: Date?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            titleHeader
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
        // 빨강 톤은 ring·컨트롤 등 메인 요소에만 명시적으로 박는다 — 탭 루트에 .tint(.red)를
        // 걸면 자식 시트(세션 목록)의 X/+ 버튼까지 빨강이 전파돼 디자인 분리를 못 한다.
        // 상단 "집중" nav 타이틀도 제거 — 본문 상단에 세션 타이틀이 자리잡는다.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSessions = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .tint(.red)
                .accessibilityLabel("세션")
                // 세션 진행 중엔 목록을 잠근다 — 다른 세션으로 갈아타려면 먼저 종료해야 한다.
                .disabled(viewModel.session != nil)
            }
        }
        .task { await viewModel.onAppear() }
        .sheet(isPresented: $showingSessions) {
            FocusSessionsListSheet(viewModel: viewModel)
        }
        .onReceive(ticker) { _ in
            viewModel.session?.tick(seconds: 1)
        }
        .onChange(of: viewModel.session?.phase) { _, newPhase in
            // 단계 전환(집중 ↔ 휴식)마다 success 햅틱. nil → non-nil 변화(세션 시작)에도
            // 트리거되지만 시작 자체를 알리는 신호로 자연스럽다.
            guard newPhase != nil else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .onChange(of: viewModel.session?.isComplete) { _, completed in
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

    // MARK: - 상단 타이틀

    /// 선택된 세션의 이름. 선택 없으면 빈 자리로 둬 ring 위치를 일정하게 유지한다.
    @ViewBuilder
    private var titleHeader: some View {
        if let session = viewModel.selectedSession {
            Text(session.title)
                .font(.largeTitle.bold())
                .foregroundStyle(.red)
                .lineLimit(1)
        } else {
            Color.clear.frame(height: Spacing.xl)
        }
    }

    /// "1 / 4" — running이고 totalCycles > 1일 때만. 자리는 항상 유지.
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

    // MARK: - ring + 시간

    /// 원형 ring + 한가운데 mm:ss. idle엔 외곽 회색 ring만, running엔 그 위에 tint
    /// progress 트림이 시계 방향으로 차오른다.
    private var ringWithTime: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            if viewModel.session != nil {
                Circle()
                    .trim(from: 0, to: progress)
                    // 환경 .tint가 더 이상 빨강이 아니라 stroke 색을 명시적으로 박는다.
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
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
            Color.clear.frame(height: Spacing.lg)
        }
    }

    // MARK: - 하단 컨트롤

    /// running이면 일시정지/스킵/종료, idle이면 ▶ 시작 버튼.
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
            startButton
        }
    }

    /// idle 시 메인 화면의 시작 진입점.
    private var startButton: some View {
        Button {
            viewModel.start()
        } label: {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "play.fill")
                    .font(.title)
                    .frame(width: Spacing.xxl, height: Spacing.xxl)
                    .background(Circle().fill(Color.red.opacity(0.15)))
                    .foregroundStyle(.red)
                Text("시작")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("시작")
    }

    /// 컨트롤 단일 버튼 — 원형 배경 + 아이콘 + 라벨.
    @ViewBuilder
    private func controlButton(
        systemImage: String,
        label: String,
        tint: Color = .red,
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

    /// running 시 0(시작) → 1(단계 종료)으로 차오르는 비율. idle이면 0(트림 안 그려짐).
    private var progress: Double {
        guard let session = viewModel.session else { return 0 }
        let total = session.phaseDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - session.remaining / total))
    }

    /// "mm:ss". running이면 남은 시간, idle이면 선택 세션(또는 기본) 집중 시간을 보여준다.
    private var timeText: String {
        let seconds = viewModel.session?.remaining ?? viewModel.displayedSettings.focusDuration
        return Duration.seconds(max(0, seconds))
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    NavigationStack {
        FocusView(viewModel: FocusViewModel(dependencies: .preview))
    }
}
