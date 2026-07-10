//
//  SettingsView.swift
//  cue / Presentation
//

import StoreKit
import SwiftUI

/// 설정 탭 화면. 전역 설정을 섹션별로 보여준다.
struct SettingsView: View {
    let viewModel: SettingsViewModel
    @Environment(\.requestReview) private var requestReview

    /// 메모 LA 카드 색 — ColorPicker 선택을 로컬 @State로 동기 보관한다.
    /// (async 저장 setter를 직접 binding하면 get이 stale 값을 돌려줘 선택이 즉시 풀리는
    /// 스냅백이 생긴다. 로컬 상태로 선택을 잡고, 변경은 onChange에서 영속 저장으로 흘려보낸다.)
    @State private var memoBackgroundColor: Color = .accentColor
    @State private var memoFontColor: Color = .white

    /// 시작 탭 선택지 — 설정 탭 자신은 제외(설정 화면으로 앱을 켜는 건 의미가 없음).
    private static let startTabOptions = AppTab.allCases.filter { $0 != .settings }

    var body: some View {
        List {
            Section {
                Picker("화면 모드", selection: colorSchemeBinding) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
                Picker("시작 탭", selection: startTabBinding) {
                    ForEach(Self.startTabOptions) { tab in
                        Text(tab.title).tag(tab.rawValue)
                    }
                }
            } header: {
                sectionHeader("일반")
            }

            Section {
                Picker("글자 크기", selection: memoTextSizeBinding) {
                    ForEach(MemoTextSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                ColorPicker("라이브 배경 색", selection: $memoBackgroundColor, supportsOpacity: false)
                ColorPicker("라이브 폰트 색", selection: $memoFontColor, supportsOpacity: false)
            } header: {
                sectionHeader("메모")
            }

            Section {
                Toggle("종료 소리", isOn: focusEndSoundBinding)
            } header: {
                sectionHeader("집중")
            }
            // 앱 전역 무채색 tint(.primary)가 다크 모드에서 토글 ON 트랙을 흰색으로 만들어
            // 노브와 구분이 안 된다 — 토글만 시스템 표준(초록)으로 되돌린다.
            .tint(.green)

            Section {
                Picker("메모 표시", selection: memoShowsCalendarBinding) {
                    Text("기본").tag(false)
                    Text("캘린더 함께 표시").tag(true)
                }
                Picker("일정 표시", selection: scheduleShowsCalendarBinding) {
                    Text("기본").tag(false)
                    Text("캘린더 함께 표시").tag(true)
                }
            } header: {
                sectionHeader("라이브")
            }

            Section {
                Button("리뷰 남기기") {
                    requestReview()
                }
                Link("피드백 보내기", destination: SupportLinks.feedbackMailtoURL)
                LabeledContent("버전", value: AppVersionInfo.display)
            } header: {
                sectionHeader("지원")
            }
            // 지원 섹션의 버튼·링크 색(틴트) 제거 — 단색 텍스트로.
            .tint(.primary)
        }
        .listSectionSpacing(28)
        .navigationTitle("설정")
        .task {
            await viewModel.onAppear()
            // 저장된 hex로 ColorPicker 초기 선택을 잡는다(폴백은 위젯과 동일: 배경 accent / 글자 white).
            memoBackgroundColor = Color(hex: viewModel.memoColorHex) ?? .accentColor
            memoFontColor = Color(hex: viewModel.memoTextColorHex) ?? .white
        }
        // 선택이 바뀌면 hex로 환원해 메모에 영속 저장 — 초기 seed 시엔 같은 값이라 사실상 no-op.
        .onChange(of: memoBackgroundColor) { _, newValue in
            Task { await viewModel.setMemoColor(newValue.hexString) }
        }
        .onChange(of: memoFontColor) { _, newValue in
            Task { await viewModel.setMemoTextColor(newValue.hexString) }
        }
    }

    /// 섹션 헤더 — 기본보다 작은 글자.
    private func sectionHeader(_ title: String) -> some View {
        Text(title).font(.body.weight(.medium))
    }

    /// 섹션 풋터 설명 — 기본보다 작은 글자.
    private func sectionFooter(_ text: String) -> some View {
        Text(text).font(.caption2)
    }

    // MARK: - 바인딩
    //
    // Picker·Toggle은 동기 바인딩이라, 변경을 Task로 감싸 async 저장으로 흘려보낸다
    // (MemoViewModel의 setText/setColor와 같은 패턴).

    private var colorSchemeBinding: Binding<AppColorScheme> {
        Binding(
            get: { viewModel.settings.colorScheme },
            set: { newValue in Task { await viewModel.setColorScheme(newValue) } }
        )
    }

    private var startTabBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.startTabID },
            set: { newValue in Task { await viewModel.setStartTabID(newValue) } }
        )
    }

    private var memoTextSizeBinding: Binding<MemoTextSize> {
        Binding(
            get: { viewModel.settings.memoTextSize },
            set: { newValue in Task { await viewModel.setMemoTextSize(newValue) } }
        )
    }

    private var focusEndSoundBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.focusEndSound },
            set: { newValue in Task { await viewModel.setFocusEndSound(newValue) } }
        )
    }

    private var memoShowsCalendarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.memoShowsCalendar },
            set: { newValue in Task { await viewModel.setMemoShowsCalendar(newValue) } }
        )
    }

    private var scheduleShowsCalendarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.scheduleShowsCalendar },
            set: { newValue in Task { await viewModel.setScheduleShowsCalendar(newValue) } }
        )
    }

}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(dependencies: .preview))
    }
}
