//
//  FocusSessionView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 진행 중인 집중 세션의 풀스크린 화면 — 사이클 진행 · 남은 시간 · 단계 라벨 ·
/// 컨트롤(일시정지/스킵/종료)을 한 화면에 모은다.
///
/// 뷰는 1초마다 `session.tick(seconds: 1)`을 호출해 ViewModel이 시간을 갉도록 한다.
/// 일시정지·스킵·중단은 모두 ViewModel 메서드에 위임 — 뷰는 입력 디스패치와 표현만.
struct FocusSessionView: View {
    @Bindable var session: FocusSessionViewModel
    /// 시트 종료 콜백 — 닫기 버튼 / 세션 완료 시 부모(`FocusViewModel.stopSession`)를 부른다.
    let onDismiss: () -> Void

    /// 1초마다 publish — `tick`은 일시정지·완료 시 자체 가드로 no-op.
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// 백그라운드 진입 시각 — 복귀 시 흘러간 만큼 ViewModel에 한 번에 tick해 단계 종료
    /// 시점을 추격(catch-up)한다. 시스템 알림은 백그라운드에서 시스템이 발화하므로 화면
    /// 상태만 따로 보정해 주면 된다.
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
        .background(Color(.systemBackground))
        .onReceive(ticker) { _ in
            session.tick(seconds: 1)
        }
        .onChange(of: session.phase) { _, _ in
            // 단계 전환(집중 ↔ 휴식)마다 success 햅틱 — foreground에서 시스템 알림이
            // 묻히기 쉬워(앱이 활성이면 banner가 자동으로 안 뜨는 경우가 많다) 햅틱이
            // 사용자에게 가장 확실한 신호가 된다.
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .onChange(of: session.isComplete) { _, completed in
            // 마지막 집중이 끝나거나 abort()로 완료되면 시트를 자동으로 닫는다.
            if completed {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onDismiss()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                if backgroundedAt == nil { backgroundedAt = Date() }
            case .active:
                if let date = backgroundedAt {
                    let elapsed = Date().timeIntervalSince(date)
                    if elapsed > 0 { session.tick(seconds: elapsed) }
                    backgroundedAt = nil
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - 상단 사이클 진행

    /// "1 / 4" — 1 사이클짜리 세션엔 의미가 없어 숨긴다.
    @ViewBuilder
    private var cycleIndicator: some View {
        if session.totalCycles > 1 {
            Text("\(session.currentCycle) / \(session.totalCycles)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            // 자리 유지 — 화면이 비대칭으로 튀는 걸 방지.
            Color.clear.frame(height: Spacing.md)
        }
    }

    // MARK: - 가운데 progress 링 + 남은 시간

    /// 원형 progress + 한가운데 mm:ss. `Circle().trim`을 두 겹(배경/진행)으로 깐다.
    private var ringWithTime: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 6, lineCap: .round))
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                // 12시 방향(상단)에서 시작해 시계 방향으로 차오르도록 회전.
                .rotationEffect(.degrees(-90))
                // `linear`로 1초 tick과 발맞춰 자연스럽게.
                .animation(.linear(duration: 0.2), value: progress)

            Text(timeText)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, Spacing.xl)
    }

    /// 링 아래 단계 라벨 — "집중 중" / "휴식 중".
    private var phaseLabel: some View {
        Text(session.phase == .focus ? "집중 중" : "휴식 중")
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    // MARK: - 하단 컨트롤

    /// 일시정지/재개 · 스킵 · 종료 — iOS 시계 타이머와 유사한 3분할 구성.
    private var controlRow: some View {
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
                // 부모의 stopSession이 abort + nil을 한 번에 처리한다.
                onDismiss()
            }
        }
    }

    /// 컨트롤 단일 버튼 — 원형 배경 + 아이콘 + 라벨.
    /// `tint` 미지정이면 시스템 accent 사용.
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

    /// 현재 단계가 끝났을 때 1, 시작 시 0. linear로 한 단계 동안 0→1을 그린다.
    private var progress: Double {
        let total = session.phaseDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - session.remaining / total))
    }

    /// "mm:ss" 형식 — `Duration.TimeFormatStyle`로 시스템 로케일 의존 없이 깔끔.
    private var timeText: String {
        Duration.seconds(max(0, session.remaining))
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    FocusSessionView(
        session: FocusSessionViewModel(
            settings: FocusSettings(focusDuration: 25 * 60, restDuration: 5 * 60, isRepeating: true, cycleCount: 4),
            scheduler: NoopFocusNotificationScheduler()
        ),
        onDismiss: {}
    )
}
