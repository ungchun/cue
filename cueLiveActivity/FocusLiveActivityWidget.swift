//
//  FocusLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

/// 집중 세션 라이브 액티비티 위젯 — **placeholder UI**. 본격 디자인(원형 progress ring,
/// pause/skip 버튼, dynamic island compact 타이머)은 다음 사이클에서.
///
/// 카운트다운 표시 분기:
/// - `pauseTime`이 nil → `Text(timerInterval:countsDown:)`이 매 프레임 자체 갱신.
/// - `pauseTime`이 set → 그 시점의 잔여를 **정적 텍스트**로 표시. (iOS의
///   `Text(timerInterval:pauseTime:)`이 일부 환경에서 pauseTime을 묵묵히 무시하는 케이스가
///   있어 widget 측에서 직접 분기하는 게 안전.)
struct FocusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusLiveActivityAttributes.self) { context in
            // Lock screen / banner — 좌측 타이틀, 우측 카운트다운.
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                    Text(phaseLabel(context.state.phase))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                timerText(state: context.state)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer")
                        .foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(state: context.state)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.sessionTitle)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(phaseLabel(context.state.phase))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                timerText(state: context.state, showsHours: false)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.tint)
            }
        }
    }

    /// 카운트다운 표시 — pause 여부로 동적/정적 분기.
    /// `pauseTime`이 있으면 그 시점에서 본 잔여(`phaseEndDate - pauseTime`)를 mm:ss로 박아둔다.
    /// 없으면 시스템 자체 갱신을 사용.
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

    /// 정적 잔여 시간 포맷 — 시스템 `Text(timerInterval:)`의 표시와 같은 형식(`mm:ss` 또는
    /// `h:mm:ss`)을 유지해 pause↔resume 사이 깜박임이 최소화된다.
    private func formatRemaining(_ seconds: TimeInterval, showsHours: Bool) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if showsHours && hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        // showsHours=false (compactTrailing)면 한 시간이 넘어도 mm:ss로 — 좁은 영역이라.
        let mm = showsHours ? minutes : (hours * 60 + minutes)
        return String(format: "%02d:%02d", mm, secs)
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
