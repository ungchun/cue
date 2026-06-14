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
/// - **잠금화면 / Dynamic Island expanded**: 좌측 ⏸/▶ 토글 버튼 + 중앙 3단(타이틀 / 큰
///   카운트다운 / phase 라벨) + 우측 ✕ 종료 버튼.
/// - **Dynamic Island compact**: 좌측 `sessionColor` 진행 ring + 우측 카운트다운.
/// - **Dynamic Island minimal**: `sessionColor` 작은 timer 아이콘.
///
/// **타이머 표시 분기** — `pauseTime`이 nil이면 시스템 `Text(timerInterval:countsDown:)`이
/// OS 위임으로 매초 자동 갱신(LA는 코드 재실행 없이 이 프리미티브만 틱한다 — `TimelineView`는
/// LA에서 ~2회만 호출돼 멈춘다), set이면 그 시점 잔여를 정적 `Text`로 박아 멈춘다. 시스템
/// 타이머 텍스트는 단독으로 쓰면 가용 폭을 꽉 채우고 visible을 leading에 박아 시각 중앙이
/// 깨지므로, 바깥 `Text("\(…)")` 보간에 중첩해 inline 콘텐츠로 만든 뒤
/// `.multilineTextAlignment(.center)`로 중앙 정렬한다(Apple 포럼 확인된 우회).
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
                    expandedStack(context: context)
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

    /// 잠금화면 LA — centerStack을 size 결정 베이스로 두고 버튼 HStack을 overlay.
    ///
    /// **왜 베이스 뒤집기** — 이전 시도들(Spacer 변형, frame, fixedSize, GeometryReader,
    /// 그리고 직전 시도인 "HStack 베이스 + centerStack overlay")은 모두 *HStack을
    /// 베이스로* 두고 중앙을 찾으려 했다. HStack 베이스에 centerStack을 overlay로 얹으면
    /// 부모 reported height = HStack height = 56pt (버튼 높이)로 collapse하고, centerStack의
    /// 위아래가 LA 클립 영역 밖으로 사라진다 (타이머·휴식 중 라벨이 안 보이는 증상).
    ///
    /// 베이스를 centerStack으로 바꾸면 부모 height = centerStack height가 보장되고,
    /// `.frame(maxWidth: .infinity)`로 폭을 LA 전체로 확장하면 centerStack 컨텐츠는
    /// 그 frame의 default `.center` 정렬로 기하 중심에 위치한다. 버튼 HStack을 그 위에
    /// overlay하면 같은 full-width × centerStack height 영역에 sized 돼서 Spacer가
    /// 좌우 edge로 버튼을 밀고, 중앙 위치는 베이스의 정체성 자체라 어긋날 여지가 없다.
    @ViewBuilder
    private func lockScreenContent(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        centerStack(context: context)
            .frame(maxWidth: .infinity)
            .overlay {
                HStack {
                    pauseResumeButton(state: context.state)
                    Spacer()
                    endButton
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
    }

    /// Dynamic Island expanded 전용 세로 3단 — 타이틀(top) / 타이머+좌우 버튼(center) /
    /// phase 라벨(bottom).
    ///
    /// **잠금화면 `centerStack`과 다른 점** — `centerStack`은 버튼이 타이틀·타이머·라벨
    /// *전체*를 좌우로 감싸서 타이틀이 버튼 사이 행에 갇힌다. expanded에선 타이틀을 맨 위,
    /// 라벨을 맨 아래로 보내야 하므로 *가운데 행만* `HStack{버튼 · 타이머 · 버튼}`으로 두고
    /// 타이틀·라벨을 그 위아래 독립 행에 둔다. 버튼은 타이머 행에 수직 정렬돼 정중앙에 온다.
    @ViewBuilder
    private func expandedStack(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(context.attributes.sessionTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: Spacing.md) {
                pauseResumeButton(state: context.state)
                Spacer(minLength: Spacing.zero)
                timerText(state: context.state)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.zero)
                endButton
            }
            Text(phaseLabel(context.state.phase))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 중앙 3단 — 세션 타이틀(상단) / 큰 mm:ss 카운트다운(중간) / phase 라벨(하단).
    ///
    /// **디자인 시스템 예외 — 카운트다운 폰트 크기**: 잠금화면 LA의 시각 무게 중심이라
    /// 텍스트 스타일 최대(`.largeTitle` ≈ 34pt)보다 크게. 메인 앱 FocusView의 56pt와
    /// 동일 패턴으로 `.system(size:)`를 명시.
    private func centerStack(
        context: ActivityViewContext<FocusLiveActivityAttributes>
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(context.attributes.sessionTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            timerText(state: context.state)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(phaseLabel(context.state.phase))
                .font(.caption)
                .foregroundStyle(.secondary)
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
    ///
    /// `.scaleEffect(x: -1)` — 링을 수평 미러해 진행 회전 방향을 반대로(시계↔반시계) 뒤집는다.
    /// 대칭 ring이라 미러의 유일한 가시 효과는 방향 반전이다.
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
        .scaleEffect(x: -1, y: 1)
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

    /// 카운트다운 표시 — pause 여부로 정적/시스템타이머 분기.
    ///
    /// **running 분기**: 시스템 `Text(timerInterval:countsDown:)`이 LA에서 OS 위임으로 매초
    /// 자동 갱신된다(코드 재실행 없이 틱하는 유일한 텍스트 프리미티브 — `TimelineView`는 LA에서
    /// ~2회만 호출돼 멈춘다, FB15590204). 단독으로 쓰면 가용 폭을 꽉 채우고 visible을 leading에
    /// 박아 시각 중앙이 깨지므로, 바깥 `Text("\(…)")` 보간에 중첩해 inline 콘텐츠로 만든 뒤
    /// `.multilineTextAlignment(.center)`로 중앙 정렬한다(Apple 포럼 확인된 우회).
    ///
    /// **pause 분기**: `pauseTime` 시점 잔여(`phaseEndDate - pauseTime`)를 `formatRemaining`으로
    /// 정적 박아 멈춘다.
    @ViewBuilder
    private func timerText(
        state: FocusLiveActivityAttributes.ContentState,
        showsHours: Bool = true
    ) -> some View {
        if let pauseTime = state.pauseTime {
            let remaining = max(0, state.phaseEndDate.timeIntervalSince(pauseTime))
            Text(formatRemaining(remaining, showsHours: showsHours))
                .multilineTextAlignment(.center)
        } else {
            Text("\(Text(timerInterval: state.phaseStartDate...state.phaseEndDate, countsDown: true, showsHours: showsHours))")
                .multilineTextAlignment(.center)
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

    /// attributes의 `colorHex` → SwiftUI Color. 미지정/디코드 실패 시 앱 프라이머리로 폴백.
    ///
    /// 폴백을 `.accentColor`가 아니라 `Color.indigo`로 명시 — Live Activity 렌더 컨텍스트에서
    /// `.accentColor`는 익스텐션 AccentColor 에셋을 안정적으로 따라가지 못해 시스템 파랑으로
    /// 떨어진다. 앱 프라이머리(AccentColor = `#5856D6`)는 systemIndigo와 동일하므로 Apple
    /// 시스템 컬러 `Color.indigo`로 박아 LA에서도 동일한 보라로 보장한다(디자인 규칙 준수).
    private func sessionColor(attributes: FocusLiveActivityAttributes) -> Color {
        guard let hex = attributes.colorHex, let color = Color(hex: hex) else {
            return .indigo
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
