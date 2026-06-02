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
        // 단순한 VStack 자연 layout — 모든 자식이 `Spacing.xl` 균등 spacing, 화면 maxHeight에서
        // 자연 center 정렬. ring 크기는 `.padding(.horizontal, .xxl)`(화면 ~76%)로 결정되고
        // ring center 위치는 콘텐츠 center를 따라간다(정확한 화면 정중앙 강제 안 함 — 시각상
        // 자연스러움 우선). idle 시 phaseLabel은 렌더링 안 해 자리도 안 차지하므로 시작 버튼이
        // ring 가까이로 자연 이동.
        VStack(spacing: Spacing.xxl) {
            titleHeader
            ringWithTime
            controlRow
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 빨강 톤은 ring·컨트롤 등 메인 요소에만 명시적으로 박는다 — 탭 루트에 .tint(.red)를
        // 걸면 자식 시트(세션 목록)의 X/+ 버튼까지 빨강이 전파돼 디자인 분리를 못 한다.
        // 상단 "집중" nav 타이틀도 제거 — 본문 상단에 세션 타이틀이 자리잡는다.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSessions = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
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

    /// 선택된 세션의 이름. 선택 없으면 앱 이름 "Cue"를 placeholder처럼 둔다.
    /// 디자인 시스템 예외 — 타이틀은 ring 안 타이머(56pt)와의 시각 위계를 위해
    /// `.largeTitle`(≈34pt)보다 살짝 큰 40pt로 명시. 타이머 < 타이틀 위계는 깨지지 않게.
    /// `Text`의 자동 frame은 line height(≈48pt)만큼 잡혀 폰트의 ascent/descent 비대칭이
    /// 시각 위·아래 padding 차이로 노출된다 — visual text에 가까운 `Spacing.xl(32)`로 박아
    /// 양쪽 padding이 같아 보이게 한다 (phaseLabel과 동일 패턴).
    private var titleHeader: some View {
        Text(viewModel.selectedSession?.title ?? "Cue")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .foregroundStyle(viewModel.selectedSession == nil ? Color.secondary : sessionColor)
            .lineLimit(1)
            .frame(height: Spacing.xxl)
    }

    /// 선택된 세션의 색. 세션이 없거나 hex 파싱 실패 시 시스템 기본 accent로 폴백 —
    /// 메인 타이틀·ring 트림·컨트롤 버튼이 모두 이 한 가지 색으로 통일된다.
    private var sessionColor: Color {
        guard let hex = viewModel.selectedSession?.colorHex,
              let color = Color(hex: hex) else { return .accentColor }
        return color
    }

    // MARK: - ring + 시간

    /// 원형 ring + 한가운데에 큰 mm:ss 타이머와 그 바로 아래 cycle 표시("1 / 4")가 겹쳐 보인다.
    /// idle엔 외곽 회색 ring만 보이고, running엔 그 위로 tint progress 트림이 시계 방향으로 차오른다.
    /// `aspectRatio(1, fit)` + `.padding(.horizontal, .xxl)`로 자체 size 결정 — 화면 너비의
    /// 약 76%(`너비 - 2 * .xxl`)가 ring 외경이 된다.
    private var ringWithTime: some View {
        ZStack {
            // `strokeBorder`는 stroke를 frame 안쪽으로만 그린다 — `stroke`는 path 양쪽으로 그려져
            // visual 호 외측이 frame edge 밖으로 lineWidth/2(=8pt) 나가버린다. 그 결과 VStack
            // spacing이 ring 호 visual edge가 아니라 frame edge 기준으로 잡혀 시각이 비대칭.
            // 진행 trim 원도 같은 시각 외측을 갖도록 `inset(by: 8)` 후 stroke center로 맞춘다.
            Circle()
                .strokeBorder(Color(.systemGray5), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            if viewModel.session != nil {
                Circle()
                    .inset(by: 8)
                    .trim(from: 0, to: progress)
                    // 선택된 세션 색으로 — 타이틀과 같은 톤이라 어느 세션이 도는지 즉시 인지.
                    .stroke(sessionColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: progress)
            }
            VStack(spacing: Spacing.sm) {
                phaseLabelInRing
                // 디자인 시스템 예외 — 타이머는 화면의 시각 무게 중심이라 텍스트 스타일 최대치
                // (`.largeTitle` ≈ 34pt)로는 부족하다. `.system(size:)`를 명시 — `system(.largeTitle, ...)`로는
                // 같은 텍스트 스타일이라 크기가 안 늘어난다.
                Text(timeText)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                cycleIndicatorInRing
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, Spacing.sm)
    }

    /// ring 안 타이머 바로 아래의 사이클 표시 — running + 다회 세션에서만 나타난다.
    /// 자리는 차지하지 않고, 안 보이는 동안엔 타이머가 ring 정중앙으로 자연스레 자리잡는다.
    @ViewBuilder
    private var cycleIndicatorInRing: some View {
        if let session = viewModel.session, session.totalCycles > 1 {
            Text("\(session.currentCycle) / \(session.totalCycles)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// ring 안 타이머 위쪽 단계 라벨 — running일 때만 "집중 중" / "휴식 중". idle엔 렌더링
    /// 자체를 안 해 ring 안 timer가 정중앙으로 자연 정렬된다.
    @ViewBuilder
    private var phaseLabelInRing: some View {
        if let session = viewModel.session {
            Text(session.phase == .focus ? "집중 중" : "휴식 중")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 하단 컨트롤

    /// running이면 일시정지/스킵/종료, idle이면 ▶ 시작 버튼.
    /// 모든 버튼은 `sessionColor` 한 가지 톤으로 통일 — 선택된 세션의 색(없으면 시스템 accent)에
    /// 맞춰 ring 트림·타이틀과 시각적으로 묶인다.
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

                controlButton(systemImage: "xmark", label: "종료") {
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
                    .background(Circle().fill(sessionColor.opacity(0.15)))
                    .foregroundStyle(sessionColor)
                Text("시작")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("시작")
    }

    /// 컨트롤 단일 버튼 — 원형 배경 + 아이콘 + 라벨. tint는 항상 `sessionColor`.
    private func controlButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: Spacing.xxl, height: Spacing.xxl)
                    .background(Circle().fill(sessionColor.opacity(0.15)))
                    .foregroundStyle(sessionColor)
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
