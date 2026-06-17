//
//  FocusAlarmLiveActivityWidget.swift
//  cueLiveActivity
//
//  AlarmKit이 구동하는 집중 세션 Live Activity.
//
//  ActivityConfiguration 등록은 AlarmKit **필수**(없으면 카운트다운 LA 미표시 + 상태 변경 시 시스템이
//  알람 dismiss). 뷰만 우리가 그리고 데이터·구동은 전적으로 AlarmKit(`context.state.mode`)이 한다.
//  버튼은 공식 샘플대로 `Button(intent:)` + `state.alarmID`로 AlarmManager 제어.
//
//  UI는 기존 Focus LA 디자인 — 중앙에 큰 라운드 카운트다운, **좌측 일시정지/재개 · 우측 종료** 원형
//  아이콘 버튼이 시간을 사이에 두고 좌우에 배치. 상단 세션 타이틀, 하단 단계·사이클.
//

import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

struct FocusAlarmLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<FocusAlarmMetadata>.self) { context in
            lockScreen(context: context)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    expanded(context: context)
                }
            } compactLeading: {
                compactRing(context.state, color: color(context))
            } compactTrailing: {
                countdown(context.state).monospacedDigit().frame(maxWidth: 44)
            } minimal: {
                compactRing(context.state, color: color(context))
            }
        }
    }

    // MARK: - Lock screen — 중앙 시간 + 좌우 버튼

    /// centerStack을 베이스로 두고 버튼 HStack을 overlay — 시간이 기하 중심에 오고 좌우 버튼이
    /// edge로 밀린다(기존 Focus LA와 동일 패턴).
    private func lockScreen(
        context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>
    ) -> some View {
        centerStack(context: context)
            .frame(maxWidth: .infinity)
            .overlay {
                HStack {
                    leftButton(context.state)
                    Spacer()
                    stopButton(context.state)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
    }

    private func centerStack(
        context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>
    ) -> some View {
        VStack(spacing: Spacing.xxs) {
            countdown(context.state)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text(subtitle(context)).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - Dynamic Island expanded — 타이틀 / [좌버튼 · 시간 · 우버튼] / 라벨

    private func expanded(
        context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>
    ) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.md) {
                leftButton(context.state)
                Spacer(minLength: Spacing.zero)
                countdown(context.state)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.zero)
                stopButton(context.state)
            }
            Text(subtitle(context)).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: - compactLeading 진행 ring (시간초에 맞춰 줄어듦)

    /// 카운트다운에 맞춰 차는/줄어드는 원형 ring. `ProgressView(timerInterval:)`이 시스템 위임으로
    /// 자동 갱신(앱 코드 없이 틱). `.scaleEffect(x: -1)`로 진행 회전 방향 반전(기존 디자인).
    @ViewBuilder
    private func compactRing(_ state: AlarmPresentationState, color: Color) -> some View {
        switch state.mode {
        case .countdown(let c):
            let end = c.fireDate
            let start = end.addingTimeInterval(-c.totalCountdownDuration)
            ProgressView(
                timerInterval: start...end,
                countsDown: true,
                label: { EmptyView() },
                currentValueLabel: { EmptyView() }
            )
            .progressViewStyle(.circular)
            .tint(color)
            .scaleEffect(x: -1, y: 1)
        case .paused(let p):
            let frac = p.totalCountdownDuration > 0
                ? max(0, min(1, 1 - p.previouslyElapsedDuration / p.totalCountdownDuration))
                : 0
            ProgressView(value: frac)
                .progressViewStyle(.circular)
                .tint(color)
                .scaleEffect(x: -1, y: 1)
        case .alert:
            Image(systemName: "timer").foregroundStyle(color)
        @unknown default:
            Image(systemName: "timer").foregroundStyle(color)
        }
    }

    // MARK: - 모드별 카운트다운 (시스템이 채운 state를 그릴 뿐)

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        switch state.mode {
        case .countdown(let c):
            let now = Date.now
            if c.fireDate > now {
                Text(timerInterval: now...c.fireDate, countsDown: true)
                    .multilineTextAlignment(.center)
            } else {
                Text("00:00")
            }
        case .paused(let p):
            Text(format(max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)))
        case .alert:
            Text("00:00")
        @unknown default:
            Text("--:--")
        }
    }

    // MARK: - 버튼 (좌: 일시정지/재개, 우: 종료) — 원형 아이콘

    /// 좌측 — countdown이면 일시정지, paused면 재개, alert면 자리만 비움(레이아웃 유지).
    @ViewBuilder
    private func leftButton(_ state: AlarmPresentationState) -> some View {
        let id = state.alarmID.uuidString
        switch state.mode {
        case .countdown:
            iconButton("pause.fill", bg: Color.secondary.opacity(0.3), fg: .white,
                       intent: FocusAlarmPauseIntent(alarmID: id), label: "일시정지")
        case .paused:
            iconButton("play.fill", bg: Color.secondary.opacity(0.3), fg: .white,
                       intent: FocusAlarmResumeIntent(alarmID: id), label: "재개")
        case .alert:
            Color.clear.frame(width: 56, height: 56)
        @unknown default:
            Color.clear.frame(width: 56, height: 56)
        }
    }

    /// 우측 — 종료(빨강 원 ✕).
    private func stopButton(_ state: AlarmPresentationState) -> some View {
        iconButton("xmark", bg: .red, fg: .white,
                   intent: FocusAlarmStopIntent(alarmID: state.alarmID.uuidString), label: "종료")
    }

    private func iconButton<I: AppIntent>(
        _ image: String,
        bg: Color,
        fg: Color,
        intent: I,
        label: String
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: image)
                .font(.title)
                .frame(width: 56, height: 56)
                .background(Circle().fill(bg))
                .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private func subtitle(_ context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>) -> String {
        guard let meta = context.attributes.metadata else { return "" }
        let phase = meta.phase == .focus ? "집중" : "휴식"
        return meta.totalCycles > 1 ? "\(phase) · \(meta.cycle) / \(meta.totalCycles)" : phase
    }

    private func color(_ context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>) -> Color {
        context.attributes.tintColor
    }

    private func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
