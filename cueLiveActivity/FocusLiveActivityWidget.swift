//
//  FocusLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// 집중 세션 라이브 액티비티 위젯.
///
/// **레이아웃**:
/// - **잠금화면 / Dynamic Island expanded**: 외곽 `sessionColor` stroke의 둥근 사각형 안에
///   좌측 ⏸/▶ 토글 버튼 + 중앙 3단(타이틀 / 큰 카운트다운 / phase 라벨) + 우측 ✕ 종료 버튼.
/// - **Dynamic Island compact**: 좌측 `sessionColor` 진행 ring + 우측 카운트다운.
/// - **Dynamic Island minimal**: `sessionColor` 작은 timer 아이콘.
///
/// **타이머 표시 분기** — `pauseTime`이 nil이면 `Text(timerInterval:countsDown:)`이
/// 시스템 위임으로 매 프레임 자동 갱신, set이면 그 시점의 잔여를 정적 텍스트로 박는다.
/// (iOS의 `Text(timerInterval:pauseTime:)`이 일부 환경에서 pauseTime을 묵묵히 무시하는 케이스
/// 우회 — widget이 직접 분기.)
///
/// **App Intent 버튼** — `PauseResumeFocusIntent` / `EndFocusIntent`이 큐에 enqueue하고
/// 시각 피드백을 위한 LA `update`를 즉시 보낸다. 메인 앱이 active되면 큐를 drain해
/// `FocusViewModel.handleLiveActivityActions(_:)`로 상태에 정확히 반영.
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            lockScreenContent(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    expandedContent(context: context)
                }
            } compactLeading: {
                compactRing(context: context)
            } compactTrailing: {
                compactCountdown(state: context.state)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(sessionColor(attributes: context.attributes))
            }
        }
    }

    // MARK: - Lock screen / Expanded

    /// 잠금화면 표시. expanded와 동일 구조 — 외곽 sessionColor stroke + 3 column.
    @ViewBuilder
    private func lockScreenContent(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: Spacing.md) {
            pauseResumeButton(state: context.state)
            Spacer(minLength: Spacing.zero)
            centerStack(context: context)
            Spacer(minLength: Spacing.zero)
            endButton
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.md)
        .overlay {
            RoundedRectangle(cornerRadius: Spacing.xl, style: .continuous)
                .strokeBorder(sessionColor(attributes: context.attributes), lineWidth: 4)
        }
        .padding(Spacing.xs)
    }

    /// Dynamic Island expanded center — 잠금화면과 같은 3 column 구조(외곽 stroke 없음:
    /// expanded 자체에 시스템이 둥근 컨테이너를 입힘).
    @ViewBuilder
    private func expandedContent(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        HStack(spacing: Spacing.md) {
            pauseResumeButton(state: context.state)
            Spacer(minLength: Spacing.zero)
            centerStack(context: context)
            Spacer(minLength: Spacing.zero)
            endButton
        }
        .padding(.horizontal, Spacing.sm)
    }

    /// 중앙 3단 — 세션 타이틀(상단) / 큰 mm:ss 카운트다운(중간) / phase 라벨(하단).
    private func centerStack(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(context.attributes.sessionTitle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            timerText(state: context.state)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(phaseLabel(context.state.phase))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// 좌측 일시정지/재개 버튼 — `pauseTime` 유무로 아이콘 토글, 액션은 단일 intent.
    private func pauseResumeButton(state: FocusLiveActivityAttributes.ContentState) -> some View {
        Button(intent: PauseResumeFocusIntent()) {
            Image(systemName: state.pauseTime == nil ? "pause.fill" : "play.fill")
                .font(.title3)
                .frame(width: Spacing.xxl, height: Spacing.xxl)
                .background(Circle().fill(Color.secondary.opacity(0.3)))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.pauseTime == nil ? "일시정지" : "재개")
    }

    /// 우측 종료 버튼 — destructive 컨벤션대로 .red 배경.
    private var endButton: some View {
        Button(intent: EndFocusIntent()) {
            Image(systemName: "xmark")
                .font(.title3)
                .frame(width: Spacing.xxl, height: Spacing.xxl)
                .background(Circle().fill(Color.red))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("종료")
    }

    // MARK: - Compact / Minimal

    /// compactLeading — sessionColor 진행 ring. `ProgressView(timerInterval:)`이 시스템 위임으로
    /// 자동 갱신. pause 시엔 진행이 멈춰 보이는 게 자연.
    private func compactRing(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        ProgressView(
            timerInterval: context.state.phaseStartDate...context.state.phaseEndDate,
            countsDown: true,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
        )
        .progressViewStyle(.circular)
        .tint(sessionColor(attributes: context.attributes))
    }

    /// compactTrailing — 카운트다운 텍스트. pause 분기는 `timerText` 헬퍼 사용.
    private func compactCountdown(
        state: FocusLiveActivityAttributes.ContentState
    ) -> some View {
        timerText(state: state, showsHours: false)
            .monospacedDigit()
            .frame(maxWidth: 44)
    }

    // MARK: - Helpers

    /// 카운트다운 표시 — pause 여부로 동적/정적 분기.
    /// `pauseTime`이 있으면 그 시점의 잔여(`phaseEndDate - pauseTime`)를 mm:ss로 박아둔다.
    @ViewBuilder
    private func timerText(
        state: FocusLiveActivityAttributes.ContentState,
        showsHours: Bool = true
    ) -> some View {
        if let pauseTime = state.pauseTime {
            let remaining = max(0, state.phaseEndDate.timeIntervalSince(pauseTime))
            Text(formatRemaining(remaining, showsHours: showsHours))
        } else {
            Text(
                timerInterval: state.phaseStartDate...state.phaseEndDate,
                countsDown: true,
                showsHours: showsHours
            )
        }
    }

    /// 정적 잔여 포맷 — pause 시 시스템 `Text(timerInterval:)` 표시 형식과 호환.
    private func formatRemaining(_ seconds: TimeInterval, showsHours: Bool) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if showsHours && hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        let mm = showsHours ? minutes : (hours * 60 + minutes)
        return String(format: "%02d:%02d", mm, secs)
    }

    /// attributes의 `colorHex` → SwiftUI Color. 미지정/디코드 실패 시 시스템 accent로 폴백.
    private func sessionColor(attributes: FocusLiveActivityAttributes) -> Color {
        guard let hex = attributes.colorHex, let color = Color(hex: hex) else {
            return .accentColor
        }
        return color
    }

    /// LiveFocusPhase → 사용자에게 보이는 한국어 라벨.
    private func phaseLabel(_ phase: LiveFocusPhase) -> String {
        switch phase {
        case .focus: return "집중 중"
        case .breakTime: return "휴식 중"
        case .completed: return "완료"
        }
    }
}
