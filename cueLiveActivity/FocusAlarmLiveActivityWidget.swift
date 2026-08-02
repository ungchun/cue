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
//  UI는 시스템 타이머 LA와 동일한 레이아웃 — **좌측에 [일시정지/재개][종료] 버튼 묶음(동일 크기)**,
//  우측에 단계 라벨(집중/휴식) + 큰 카운트다운(오른쪽 끝 밀착). 잠금화면은 한 HStack, Dynamic
//  Island expanded는 leading(버튼)/trailing(시간) 리전 — 카메라 양옆 L자로 위부터 채워 상단
//  여백을 없앤다. 색은 세션색(`tintColor`, 세션 없으면 앱 메인 보라) — 재생 버튼·라벨·시간에 적용.
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
                // 시스템 글래스(블러) 재질 배경 — 일정 LA와 동일한 반투명 카드 톤(전 LA 통일).
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = context.attributes.tintColor
            // 좌(버튼)·우(시간)를 leading/trailing 리전에 둔다 — 이 둘은 카메라 양옆의 "L자"
            // 영역으로 **위쪽부터** 채워져 상단 여백이 없다(애플 기본 타이머와 동일). `.center`
            // 단독은 카메라 아래에만 놓여 상단 공백이 생기므로 쓰지 않는다. 시간은 liveCountdown
            // 으로 폭이 실제 자릿수에 고정돼 좁아, trailing 리전에서 줄바꿈되지 않는다(단계 길이는
            // 편집 시트가 1~59분으로 제한하므로 최대 5자).
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    buttonGroup(context.state, tint: tint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // DI는 단계 라벨 없이 시간만 — 우측 정렬(시스템 타이머와 동일 위치).
                    // 라벨을 뺀 만큼 폭이 넉넉해 축소·말줄임 없이 들어간다.
                    liveCountdown(
                        context.state,
                        font: .system(size: 44, weight: .regular, design: .rounded),
                        tint: tint
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
                }
            } compactLeading: {
                compactRing(context.state, color: tint)
            } compactTrailing: {
                countdown(context.state).monospacedDigit().frame(maxWidth: 44)
            } minimal: {
                compactRing(context.state, color: tint)
            }
        }
    }

    // MARK: - Lock screen — 좌측 버튼 묶음 + 우측 단계·시간

    /// 좌측에 [재생·일시정지][종료] 버튼 묶음, `Spacer`로 밀어 우측에 단계 라벨(집중/휴식) +
    /// 큰 카운트다운(시간은 오른쪽 끝에 밀착). 색은 세션색(`tintColor`, 세션 없으면 앱 메인 보라).
    private func lockScreen(
        context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>
    ) -> some View {
        let tint = context.attributes.tintColor
        return HStack(spacing: Spacing.sm) {
            buttonGroup(context.state, tint: tint)
            Spacer(minLength: Spacing.sm)
            timeGroup(context, tint: tint, timeSize: 48)
        }
        .frame(maxWidth: .infinity)
        // 우측 패딩을 줄여 시간이 오른쪽 끝에 붙는다(좌측은 버튼 호흡 위해 md 유지).
        .padding(.leading, Spacing.md)
        .padding(.trailing, Spacing.sm)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - 공유 조각 — 버튼 묶음 / 단계·시간 묶음

    /// 좌측 버튼 묶음 — [재생·일시정지][종료]를 좁은 간격으로 붙인다.
    private func buttonGroup(_ state: AlarmPresentationState, tint: Color) -> some View {
        HStack(spacing: Spacing.xs) {
            leftButton(state, tint: tint)
            stopButton(state)
        }
    }

    /// 우측 단계 라벨 + 카운트다운 — 라벨은 작게, 시간은 큰 가는 폰트로 숫자 바로 옆에 밀착.
    private func timeGroup(
        _ context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>,
        tint: Color,
        timeSize: CGFloat
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.smd) {
            // 라벨은 언어마다 길이가 크게 다르다 — 한국어 "휴식"(2자) 대비 베트남어
            // "Tập trung"·인니어 "Istirahat"·포르투갈어 "Intervalo"는 9자다. 버튼 묶음과 숫자는
            // 폭이 고정이라 좁아질 때 양보하는 쪽은 라벨뿐인데, 제한이 없으면 두 줄로 접히며
            // baseline 정렬이 무너진다. 한 줄로 묶고 모자라면 줄여서 카드 밖으로 나가지 않게 한다.
            Text(phaseLabel(context))
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            liveCountdown(
                context.state,
                font: .system(size: timeSize, weight: .regular, design: .rounded),
                tint: tint
            )
            // 숫자는 줄어들지 않는다 — 공간 부족은 항상 라벨이 흡수한다.
            .layoutPriority(1)
        }
    }

    /// `Text(timerInterval:)`은 시:분:초(h:mm:ss) 기준으로 폭을 넓게 예약해, mm:ss만 보일 땐
    /// 라벨과 숫자 사이에 빈 칸이 생긴다. 보이지 않는 템플릿 텍스트로 프레임을 실제 폭에
    /// 고정하고(타이머가 이 제안 폭에 맞춰 좁게 렌더), 그 위에 우측정렬 overlay — 라벨이
    /// 숫자 바로 옆에 붙고 숫자는 오른쪽 끝에 정렬된다. `clipped`는 혹시 모를 폭 초과 안전망.
    /// (`fixedSize`는 타이머를 거대한 자연폭으로 부풀려 clip에 잘려 사라지므로 쓰지 않는다.)
    ///
    /// 템플릿은 **지금 남은 시간의 자릿수**에 맞춘다. "00:00"으로 고정하면 `4:50`처럼 4자인
    /// 값이 오른쪽 끝에 정렬되며 한 자리 폭이 라벨 쪽에 빈칸으로 남는다 — 집중(24:57)은 붙는데
    /// 휴식(4:50)만 떨어져 보이던 원인.
    private func liveCountdown(
        _ state: AlarmPresentationState,
        font: Font,
        tint: Color
    ) -> some View {
        Text(verbatim: FocusCountdownFormat.widthTemplate(remaining(state)))
            .font(font)
            .monospacedDigit()
            .hidden()
            .overlay(alignment: .trailing) {
                countdown(state)
                    .font(font)
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .multilineTextAlignment(.trailing)
            }
            .clipped()
    }

    // MARK: - compactLeading 진행 ring (시간초에 맞춰 줄어듦)

    /// 카운트다운에 맞춰 차는/줄어드는 원형 ring. `ProgressView(timerInterval:)`이 시스템 위임으로
    /// 자동 갱신(앱 코드 없이 틱). 방향은 iOS 기본(시계방향, 왼→오) — 미러 없음.
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
        case .paused(let p):
            let frac = p.totalCountdownDuration > 0
                ? max(0, min(1, 1 - p.previouslyElapsedDuration / p.totalCountdownDuration))
                : 0
            ProgressView(value: frac)
                .progressViewStyle(.circular)
                .tint(color)
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
            } else {
                Text(verbatim: FocusCountdownFormat.text(0))
            }
        case .paused(let p):
            // 일시정지는 시스템 타이머가 아니라 우리가 그린다 — 진행 중 표기(앞자리 0 없음)와
            // 같은 모양이어야 정지·재개에서 숫자가 튀지 않는다.
            Text(verbatim: FocusCountdownFormat.text(p.totalCountdownDuration - p.previouslyElapsedDuration))
        case .alert:
            Text(verbatim: FocusCountdownFormat.text(0))
        @unknown default:
            Text(verbatim: FocusCountdownFormat.text(0))
        }
    }

    /// 폭 템플릿을 고르기 위한 현재 남은 시간 — 표시되는 숫자와 자릿수가 같아야 한다.
    private func remaining(_ state: AlarmPresentationState) -> TimeInterval {
        switch state.mode {
        case .countdown(let c): return max(0, c.fireDate.timeIntervalSinceNow)
        case .paused(let p): return max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)
        case .alert: return 0
        @unknown default: return 0
        }
    }

    // MARK: - 버튼 (좌: 일시정지/재개, 우: 종료) — 원형 아이콘

    /// 좌측 — countdown이면 일시정지, paused면 재개, alert면 자리만 비움(레이아웃 유지).
    /// 세션색(`tint`)으로 채워 "이 세션 진행 중" 의미를 색으로 전달한다.
    @ViewBuilder
    private func leftButton(_ state: AlarmPresentationState, tint: Color) -> some View {
        let id = state.alarmID.uuidString
        switch state.mode {
        case .countdown:
            iconButton("pause.fill", bg: tint, fg: .white, size: 56, iconFont: .title,
                       intent: FocusAlarmPauseIntent(alarmID: id), label: "Pause")
        case .paused:
            iconButton("play.fill", bg: tint, fg: .white, size: 56, iconFont: .title,
                       intent: FocusAlarmResumeIntent(alarmID: id), label: "Resume")
        case .alert:
            Color.clear.frame(width: 56, height: 56)
        @unknown default:
            Color.clear.frame(width: 56, height: 56)
        }
    }

    /// 우측 — 종료(중립 그레이 원 ✕). 진행/재개 색과 분리해 destructive를 톤다운. 크기는
    /// 재생 버튼과 **동일(56)** — 시스템 타이머 LA처럼 좌측 두 버튼이 같은 크기로 나란히.
    private func stopButton(_ state: AlarmPresentationState) -> some View {
        iconButton("xmark", bg: Color.secondary.opacity(0.3), fg: .white, size: 56, iconFont: .title,
                   intent: FocusAlarmStopIntent(alarmID: state.alarmID.uuidString), label: "End")
    }

    private func iconButton<I: AppIntent>(
        _ image: String,
        bg: Color,
        fg: Color,
        size: CGFloat,
        iconFont: Font,
        intent: I,
        label: LocalizedStringKey
    ) -> some View {
        Button(intent: intent) {
            Image(systemName: image)
                .font(iconFont)
                .frame(width: size, height: size)
                .background(Circle().fill(bg))
                .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    /// 우측 시간 앞에 붙는 단계 라벨 — "타이머" 대신 상태에 따라 "집중"/"휴식".
    private func phaseLabel(_ context: ActivityViewContext<AlarmAttributes<FocusAlarmMetadata>>) -> LocalizedStringKey {
        guard let meta = context.attributes.metadata else { return "" }
        return meta.phase == .focus ? "Focus" : "Break"
    }
}
