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

    /// 잠금화면 표시. 외곽 sessionColor stroke가 **timer에 맞춰 차오르는** 둥근 사각형 path +
    /// 좌·우 버튼 사이 가운데 정렬된 3단 콘텐츠.
    ///
    /// **레이아웃 — HStack + Spacer 균등 배분**: 좌·우 버튼이 동일 사이즈(56pt)라 양쪽 Spacer가
    /// 같은 width를 가져 centerStack은 자연 정중앙. ZStack 절대 정렬을 쓰면 centerStack 폭이
    /// 좌·우 버튼 영역으로 침범해 overlap이 생긴다 — HStack이 visual containment를 보장.
    @ViewBuilder
    private func lockScreenContent(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        // 단순 구조: [좌 일시정지] [가운데 VStack(타이틀/타이머/phase)] [우 종료].
        // 가운데 VStack에 .frame(maxWidth: .infinity, alignment: .center)로 button 사이 영역 흡수.
        // alignment 명시 — SwiftUI default가 .center지만 widget runtime에서 명시가 안전.
        HStack(alignment: .center, spacing: 0) {
            pauseResumeButton(state: context.state)
                .frame(width: 56)
            centerStack(context: context)
                .frame(maxWidth: .infinity, alignment: .center)
            endButton
                .frame(width: 56)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.md)
        .overlay {
            timerStroke(
                state: context.state,
                color: sessionColor(attributes: context.attributes)
            )
        }
        // outer padding — LA system mask가 RoundedRect로 자르므로 content·stroke가
        // 그 mask 안쪽으로 충분히 들어와야. md(16)로 안전 영역 확보.
        .padding(Spacing.md)
    }

    /// 외곽 stroke — pause 분기. dynamic은 `TimelineView(.periodic)`이 매초 view body를 다시
    /// 평가해 그 시각의 progress로 trim. paused는 정적.
    ///
    /// **왜 TimelineView**: `ProgressView(timerInterval:) + custom ProgressViewStyle`은 widget
    /// runtime에서 fractionCompleted가 매 프레임 갱신되지 않는다(시스템 default style만 갱신
    /// 대상). `TimelineView(.periodic(by: 1))`은 widget context에서도 자체 timer로 view body가
    /// 매 schedule 시점에 재평가되어 custom path drawing에 그 시각이 그대로 흘러간다 —
    /// WidgetKit reload budget을 소비하지 않는 별도 메커니즘.
    @ViewBuilder
    private func timerStroke(
        state: FocusLiveActivityAttributes.ContentState,
        color: Color
    ) -> some View {
        if let pauseTime = state.pauseTime {
            StrokedRoundedRect(
                progress: progress(at: pauseTime, state: state),
                color: color
            )
        } else {
            // 0.5초 — 1초면 사람 눈에 뚝뚝 끊기고, 너무 짧게 가면 widget budget 영향.
            // 0.5초가 매끄러움/리소스의 보통 spot.
            TimelineView(.periodic(from: state.phaseStartDate, by: 0.5)) { context in
                StrokedRoundedRect(
                    progress: progress(at: context.date, state: state),
                    color: color
                )
            }
        }
    }

    /// 특정 시점의 phase 진행 비율 — 0(시작) → 1(종료) clamp.
    private func progress(
        at date: Date,
        state: FocusLiveActivityAttributes.ContentState
    ) -> Double {
        let total = state.phaseEndDate.timeIntervalSince(state.phaseStartDate)
        guard total > 0 else { return 0 }
        let elapsed = date.timeIntervalSince(state.phaseStartDate)
        return min(1, max(0, elapsed / total))
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
    ///
    /// **디자인 시스템 예외 — 카운트다운 폰트 크기**: 잠금화면 LA의 시각 무게 중심이라
    /// 텍스트 스타일 최대(`.largeTitle` ≈ 34pt)보다 크게. 메인 앱 FocusView의 56pt와
    /// 동일 패턴으로 `.system(size:)`를 명시.
    private func centerStack(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        // 각 row를 HStack + 양쪽 Spacer로 — `.frame(maxWidth: .infinity, alignment: .center)`가
        // widget runtime에서 효과 없는 케이스(측정상 59pt 좌측 치우침). Spacer 균등 배분이
        // 가장 결정적.
        VStack(alignment: .center, spacing: Spacing.xxs) {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(context.attributes.sessionTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                timerText(state: context.state)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(phaseLabel(context.state.phase))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    /// 좌측 일시정지/재개 버튼 — `pauseTime` 유무로 아이콘 토글, 액션은 단일 intent.
    /// 디자인 시스템 예외 — 사용자 액션 타깃이라 토큰 최대(`Spacing.xxl=48`)보다 크게 56pt.
    private func pauseResumeButton(state: FocusLiveActivityAttributes.ContentState) -> some View {
        Button(intent: PauseResumeFocusIntent()) {
            Image(systemName: state.pauseTime == nil ? "pause.fill" : "play.fill")
                .font(.title2)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.secondary.opacity(0.3)))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state.pauseTime == nil ? "일시정지" : "재개")
    }

    /// 우측 종료 버튼 — destructive 컨벤션대로 .red 배경. 일시정지 버튼과 동일 크기.
    private var endButton: some View {
        Button(intent: EndFocusIntent()) {
            Image(systemName: "xmark")
                .font(.title2)
                .frame(width: 56, height: 56)
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

// MARK: - 외곽 timer-driven stroke

/// 둥근 사각형 path를 따라 `progress` 비율만큼 stroke를 그리는 shape. `TimelineView`가
/// 매초 새 `progress`로 이 view를 다시 만들어 path 진행을 따라 stroke가 차오르는 효과.
///
/// **lineCap은 `.butt`** — round로 두면 progress가 0.0 / 1.0 부근에서 끝점이 모서리 밖으로
/// 살짝 튀어 어색하다. butt cap이 trim 진행과 가장 깔끔.
private struct StrokedRoundedRect: View {
    let progress: Double
    let color: Color

    var body: some View {
        let cornerRadius = Spacing.xl
        let lineWidth: CGFloat = 4
        ZStack {
            // 배경 — 같은 색의 옅은 stroke. 0%에서도 외곽이 보이도록.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            // progress — path 진행을 따라 trim된 stroke.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
        }
    }
}
