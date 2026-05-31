//
//  FocusSettingsSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 집중 세션을 시작하기 전에 시간·반복·사이클 수를 잡는 시트.
/// 하단 풀폭 "시작" 버튼이 시트를 닫으면서 `onStart`를 호출 — 부모의 `FocusView`가
/// `viewModel.start()`로 메인 화면 안에서 세션을 띄운다(별도 풀스크린 뷰 없음).
struct FocusSettingsSheet: View {
    @Binding var settings: FocusSettings
    let onStart: () -> Void

    /// 시트 자체 닫기 — 좌상단 "취소" 버튼이 사용한다.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                timeSection
                repeatSection
                startButtonSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }

    // MARK: - 시간

    /// 집중·휴식 시간 — Stepper로 분 단위 ±1 조정.
    /// 휴식 시간은 반복이 켜진 경우에만 노출 — 비반복은 휴식 단계 자체가 없다.
    private var timeSection: some View {
        Section("시간") {
            Stepper(
                value: $settings.focusDuration,
                in: 60...(180 * 60),
                step: 60
            ) {
                LabeledContent("집중 시간", value: minuteLabel(settings.focusDuration))
            }
            if settings.isRepeating {
                Stepper(
                    value: $settings.restDuration,
                    in: 60...(60 * 60),
                    step: 60
                ) {
                    LabeledContent("휴식 시간", value: minuteLabel(settings.restDuration))
                }
            }
        }
    }

    // MARK: - 반복

    /// 반복 on/off + (on일 때) 사이클 수.
    private var repeatSection: some View {
        Section("반복") {
            Toggle("반복", isOn: $settings.isRepeating)
            if settings.isRepeating {
                Stepper(value: $settings.cycleCount, in: 2...10) {
                    LabeledContent("사이클 수", value: "\(settings.cycleCount)회")
                }
            }
        }
    }

    // MARK: - 시작

    /// 하단 풀폭 시작 — 탭하면 시트를 닫고 부모가 메인에서 세션을 띄운다.
    private var startButtonSection: some View {
        Section {
            Button {
                onStart()
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

    private func minuteLabel(_ seconds: TimeInterval) -> String {
        "\(Int(seconds / 60))분"
    }
}

#Preview {
    struct Wrapper: View {
        @State var settings = FocusSettings.default
        var body: some View {
            FocusSettingsSheet(settings: $settings, onStart: {})
        }
    }
    return Wrapper()
}
