//
//  FocusView.swift
//  cue / Presentation
//

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

    /// 매초 tick은 **ViewModel 소유 타이머**가 구동한다 — 뷰의 `.onReceive`는 백그라운드에서
    /// 안 돌아 단계 전환을 못 시키기 때문(keep-alive로 앱이 살아 있어도). 뷰는 표시만 한다.
    ///
    /// 포그라운드 복귀 시 LA 액션 큐 drain + 즉시 tick 한 번(벽시계 추격)은 scenePhase에서.
    @Environment(\.scenePhase) private var scenePhase

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
                .disabled(viewModel.isActive)
            }
        }
        .task { await viewModel.onAppear() }
        .sheet(isPresented: $showingSessions) {
            FocusSessionsListSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.phase) { _, _ in
            // 단계 전환(집중 ↔ 휴식)마다 success 햅틱. 진행 중일 때만.
            guard viewModel.isActive else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // 백그라운드 동안 잠금화면 버튼·자동 전환으로 바뀐 알람 상태를 메인 화면에 동기화.
            viewModel.refresh()
        }
    }

    // MARK: - 상단 타이틀

    /// 선택된 세션의 이름. 선택 없으면 앱 이름 "Cue"를 placeholder처럼 둔다.
    /// 디자인 시스템 예외 — 타이틀은 ring 안 타이머(56pt)와의 시각 위계를 위해
    /// `.largeTitle`(≈34pt)보다 살짝 큰 40pt로 명시. 타이머 < 타이틀 위계는 깨지지 않게.
    /// `Text`의 자동 frame은 line height(≈48pt)만큼 잡혀 폰트의 ascent/descent 비대칭이
    /// 시각 위·아래 padding 차이로 노출된다 — visual text에 가까운 `Spacing.xl(32)`로 박아
    /// 양쪽 padding이 같아 보이게 한다 (phaseLabel과 동일 패턴).
    ///
    /// 색은 `.primary`(라이트/다크 자동 대비) — 세션 색을 ring 트림에만 남기고
    /// 타이틀·컨트롤은 무채색으로 통일해 진행 표시(ring)에만 시선이 묶이게 한다.
    private var titleHeader: some View {
        Text(viewModel.selectedSession?.title ?? "Cue")
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .frame(height: Spacing.xxl)
    }

    /// 선택된 세션의 색. 세션이 없거나 hex 파싱 실패 시 앱 메인색(`.accentColor`, 보라 계열)
    /// 으로 폴백. ring 트림과 시작·일시정지·재개 버튼의 강조색으로 함께 쓴다 — "이 세션을
    /// 켜는 액션 = 이 색"이라는 의미를 색만으로 전달한다. 세션이 없어도 무채색이 아니라 앱
    /// 메인색으로 떠 액션 버튼이 항상 강조된다.
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
            if viewModel.isActive {
                Circle()
                    .inset(by: 8)
                    .trim(from: 0, to: progress)
                    // 선택된 세션 색으로 — 타이틀과 같은 톤이라 어느 세션이 도는지 즉시 인지.
                    .stroke(sessionColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // iOS 기본과 동일 방향(왼→오)으로 통일 — trim 베이스가 오→왼이라 미러로 뒤집음.
                    .scaleEffect(x: -1, y: 1)
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
        if viewModel.isActive, viewModel.totalCycles > 1 {
            Text("\(viewModel.currentCycle) / \(viewModel.totalCycles)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// ring 안 타이머 위쪽 단계 라벨 — running일 때만 "집중 중" / "휴식 중". idle엔 렌더링
    /// 자체를 안 해 ring 안 timer가 정중앙으로 자연 정렬된다.
    @ViewBuilder
    private var phaseLabelInRing: some View {
        if viewModel.isActive {
            Text(viewModel.phase == .focus ? "집중" : "휴식")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 하단 컨트롤

    /// 컨트롤 레이아웃 — **가운데 자리 = 현재 상태의 primary 토글**, 종료는 무채색으로 분리.
    /// - **idle** — ▶ 시작(sessionColor) 단독.
    /// - **running** — [스킵] [⏸ 일시정지(sessionColor)] [종료(.secondary)].
    /// - **paused** — [스킵] [▶ 재개(sessionColor)] [종료(.secondary)].
    ///
    /// 가운데 위치를 토글 자리로 못박아두면 사용자는 같은 자리를 두 번 탭해 일시정지↔재개를
    /// 오갈 수 있다(Fitts's law — 같은 target에 반복 액션은 cost 0). 또한 시작 버튼과 같은
    /// 색(actionColor)이 재개 버튼에만 떠 있어 "이 세션을 다시 켜는 액션"이라는 의미가
    /// 색만으로 전달된다. 종료는 그레이(`.secondary`)로 톤다운해 진행/재개 액션과 시각 분리.
    @ViewBuilder
    private var controlRow: some View {
        if viewModel.isActive {
            HStack(spacing: Spacing.xl) {
                controlButton(systemImage: "forward.end.fill", label: "스킵") {
                    viewModel.skip()
                }
                if viewModel.isPaused {
                    controlButton(systemImage: "play.fill", label: "재개", tint: sessionColor) {
                        viewModel.resume()
                    }
                } else {
                    controlButton(systemImage: "pause.fill", label: "일시정지", tint: sessionColor) {
                        viewModel.pause()
                    }
                }
                controlButton(systemImage: "xmark", label: "종료", tint: .secondary) {
                    viewModel.stopSession()
                }
            }
        } else {
            startButton
        }
    }

    /// idle 시 메인 화면의 시작 진입점. **`sessionColor`로 강조** — 재개 버튼과 같은
    /// 색이라 "이 세션을 켜는 액션 = 이 색"이라는 일관된 의미를 만든다. 세션이 없으면
    /// 앱 메인색(`.accentColor`)으로 폴백한다.
    private var startButton: some View {
        // 무채색 톤은 .12, 채도 있는 sessionColor는 .15 — controlButton과 동일 보정.
        let color = sessionColor
        let fillOpacity: Double = color == .primary ? 0.12 : 0.15
        return Button {
            viewModel.start()
        } label: {
            VStack(spacing: Spacing.md) {
                Image(systemName: "play.fill")
                    .font(.title)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(color.opacity(fillOpacity)))
                    .foregroundStyle(color)
                Text("시작")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("시작")
    }

    /// 컨트롤 단일 버튼 — 원형 배경 + 아이콘 + `.secondary` 라벨. tint 기본 `.primary`
    /// 무채색. 재개 버튼처럼 강조가 필요한 경우 `tint: sessionColor`로 호출.
    private func controlButton(
        systemImage: String,
        label: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        // 무채색 톤은 .12, 채도 있는 sessionColor는 .15 — 동일 alpha면 sessionColor 쪽이
        // 시각상 더 옅게 깔리기 때문에 보정.
        let fillOpacity: Double = tint == .primary ? 0.12 : 0.15
        return Button(action: action) {
            VStack(spacing: Spacing.md) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(tint.opacity(fillOpacity)))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - 계산값

    /// running 시 0(시작) → 1(단계 종료)으로 차오르는 비율. idle이면 0(트림 안 그려짐).
    private var progress: Double {
        guard viewModel.isActive else { return 0 }
        let total = viewModel.phaseDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - viewModel.remaining / total))
    }

    /// "mm:ss". running이면 남은 시간, idle이면 선택 세션(또는 기본) 집중 시간을 보여준다.
    /// **올림(ceil)** 표시 — LA의 시스템 `Text(timerInterval:)`도 올림으로 카운트다운하므로,
    /// 분수 초(`phaseEndDate - now`) 구간에서 앱과 LA가 같은 숫자를 띄워 싱크가 맞는다.
    private var timeText: String {
        let seconds = viewModel.isActive ? viewModel.remaining : viewModel.displayedSettings.focusDuration
        return Duration.seconds(max(0, seconds.rounded(.up)))
            .formatted(.time(pattern: .minuteSecond))
    }
}

#Preview {
    NavigationStack {
        FocusView(viewModel: FocusViewModel(dependencies: .preview))
    }
}
