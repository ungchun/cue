//
//  FocusView.swift
//  cue / Presentation
//

import SwiftUI

/// 집중 탭의 idle 화면 — 다음 세션의 설정(집중·휴식 시간, 반복, 사이클 수)을 잡고
/// "시작"을 누르면 풀스크린 시트로 `FocusSessionView`를 띄운다.
///
/// 알림 권한은 화면 진입 시 한 번 요청한다.
struct FocusView: View {
    @Bindable var viewModel: FocusViewModel

    var body: some View {
        // 일정·할일은 콘텐츠 리스트라 `.plain` + List 내부 large title을 쓰지만,
        // 집중은 settings 성격이라 `.insetGrouped` + nav bar 표준 large title이 자연스럽다.
        // Stepper/Toggle/LabeledContent는 grouped 셀 위에서 가장 보기 좋게 그려진다.
        List {
            timeSection
            repeatSection
            startButtonSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("집중")
        .task { await viewModel.onAppear() }
        .fullScreenCover(item: $viewModel.session) { session in
            FocusSessionView(session: session) {
                viewModel.stopSession()
            }
        }
    }

    // MARK: - 시간 섹션

    /// 집중·휴식 시간 — Stepper로 분 단위 ±1 조정.
    /// 휴식 시간은 반복이 켜진 경우에만 보여 — 비반복은 휴식 단계 자체가 없어 의미가 없다.
    private var timeSection: some View {
        Section("시간") {
            Stepper(
                value: $viewModel.settings.focusDuration,
                in: 60...(180 * 60),
                step: 60
            ) {
                LabeledContent("집중 시간", value: minuteLabel(viewModel.settings.focusDuration))
            }
            if viewModel.settings.isRepeating {
                Stepper(
                    value: $viewModel.settings.restDuration,
                    in: 60...(60 * 60),
                    step: 60
                ) {
                    LabeledContent("휴식 시간", value: minuteLabel(viewModel.settings.restDuration))
                }
            }
        }
    }

    // MARK: - 반복 섹션

    /// 반복 on/off + (on일 때) 사이클 수.
    private var repeatSection: some View {
        Section("반복") {
            Toggle("반복", isOn: $viewModel.settings.isRepeating)
            if viewModel.settings.isRepeating {
                Stepper(value: $viewModel.settings.cycleCount, in: 2...10) {
                    LabeledContent("사이클 수", value: "\(viewModel.settings.cycleCount)회")
                }
            }
        }
    }

    // MARK: - 시작

    /// 하단 풀폭 시작 버튼. 시스템 `borderedProminent`로 다른 탭의 강조 버튼과 톤을 맞춘다.
    private var startButtonSection: some View {
        Section {
            Button {
                viewModel.start()
            } label: {
                Text("시작")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .listRowInsets(.init(top: Spacing.md, leading: Spacing.md, bottom: Spacing.md, trailing: Spacing.md))
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - helpers

    /// 초 → "N분" 라벨. 분 단위가 핵심이라 1분 미만은 표시되지 않는다(스텝퍼 최소가 60s).
    private func minuteLabel(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 60))분"
    }
}

// MARK: - Identifiable shim

/// `.fullScreenCover(item:)`이 요구하는 Identifiable — 세션 한 건은 ViewModel 1개라
/// `ObjectIdentifier`를 그대로 id로 노출한다.
extension FocusSessionViewModel: Identifiable {
    nonisolated public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    NavigationStack {
        FocusView(viewModel: FocusViewModel(dependencies: .preview))
    }
}
