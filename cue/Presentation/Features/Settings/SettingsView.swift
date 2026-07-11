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
    @Environment(\.toastCenter) private var toastCenter

    /// 유료(Premium) 전용 설정 게이트 — 결제 도입 전이라 전원 무료 취급(항상 차단 + "Premium" 토스트).
    /// TODO: 결제/구독 도입 시 실제 엔타이틀먼트 확인으로 교체.
    private let isPremiumUser = false

    /// 메모 LA 카드 색 — ColorPicker 선택을 로컬 @State로 동기 보관한다.
    /// (async 저장 setter를 직접 binding하면 get이 stale 값을 돌려줘 선택이 즉시 풀리는
    /// 스냅백이 생긴다. 로컬 상태로 선택을 잡고, 변경은 onChange에서 영속 저장으로 흘려보낸다.)
    @State private var memoBackgroundColor: Color = .accentColor
    @State private var memoFontColor: Color = .white

    /// "24시간 사용하기" 시트 표시 — 내용은 추후 채운다(현재 빈 시트).
    @State private var shows24HourSheet = false

    /// Premium 배너 탭 시 페이월 시트 — 내용은 추후 채운다(현재 빈 시트).
    @State private var showsPremiumSheet = false


    /// 시작 탭 선택지 — 설정 탭 자신은 제외(설정 화면으로 앱을 켜는 건 의미가 없음).
    private static let startTabOptions = AppTab.allCases.filter { $0 != .settings }

    var body: some View {
        List {
            // Cue Premium 배너 — 설정 타이틀 바로 아래. 탭하면 페이월 시트(내용 추후).
            Section {
                PremiumBannerView {
                    showsPremiumSheet = true
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            // 배너 아래 간격은 전역(28)보다 좁게 — 리스트 간격 값이라 28처럼 리터럴(20).
            .listSectionSpacing(20)

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
                // 항상 표시 로직 연결은 추후 — 지금은 설정 저장까지. Premium 게이트도 추후 복원.
                Toggle("라이브 항상 표시", isOn: liveAlwaysOnBinding)
                    .tint(.green)
                // 대상 선택 — 행 하나, 메뉴에서 다중 체크(메뉴 안 Toggle은 체크마크로 렌더).
                // 라벨은 행에 남고 메뉴 앵커는 우측 값 부분만 — 시스템 Picker 행과 동일하게
                // 팝업이 오른쪽 값 위에 뜬다. 마스터 off면 비활성화(회색)로 선택만 막는다.
                LabeledContent("항목") {
                    Menu {
                        Toggle("메모", isOn: liveAlwaysOnMemoBinding)
                        Toggle("할일", isOn: liveAlwaysOnReminderBinding)
                        Toggle("일정", isOn: liveAlwaysOnScheduleBinding)
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(liveKindsSummary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .disabled(!viewModel.settings.liveAlwaysOn)
                Button("24시간 사용하기") {
                    shows24HourSheet = true
                }
                .foregroundStyle(.primary)
            } header: {
                sectionHeader("라이브")
            }

            Section {
                Picker("글자 크기", selection: memoTextSizeBinding) {
                    ForEach(MemoTextSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                premiumGated {
                    ColorPicker("라이브 배경 색", selection: $memoBackgroundColor, supportsOpacity: false)
                }
                premiumGated {
                    ColorPicker("라이브 폰트 색", selection: $memoFontColor, supportsOpacity: false)
                }
                // 켜기는 Premium 전용 — 바인딩 setter가 가로채 Premium 토스트만 띄운다(끄기는 항상 허용).
                Toggle("캘린더 함께 보기", isOn: memoShowsCalendarBinding)
                    .tint(.green)
            } header: {
                sectionHeader("메모")
            }

            Section {
                Toggle("캘린더 함께 보기", isOn: scheduleShowsCalendarBinding)
                    .tint(.green)
            } header: {
                sectionHeader("일정")
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
        // 타이틀↔배너 간격 — 배너 아래 간격과 같은 20.
        .contentMargins(.top, 20, for: .scrollContent)
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
        // "24시간 사용하기" — 단축어 자동화로 LA 8시간 종료를 우회하는 가이드.
        .sheet(isPresented: $shows24HourSheet) {
            Live24HourGuideView()
        }
        // Premium 페이월 — 가치 → 플랜 → CTA. 결제 연결은 추후.
        .sheet(isPresented: $showsPremiumSheet) {
            PremiumPaywallView()
        }
    }


    /// 표시 대상 요약 — 선택된 종류를 행 우측에 보여준다("메모, 일정" / "전체").
    private var liveKindsSummary: String {
        let selected = [
            viewModel.settings.liveAlwaysOnMemo ? "메모" : nil,
            viewModel.settings.liveAlwaysOnReminder ? "할일" : nil,
            viewModel.settings.liveAlwaysOnSchedule ? "일정" : nil,
        ].compactMap(\.self)
        if selected.count == 3 { return "전체" }
        return selected.joined(separator: ", ")
    }

    private var liveAlwaysOnMemoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnMemo },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnMemo(newValue) } }
        )
    }

    private var liveAlwaysOnReminderBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnReminder },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnReminder(newValue) } }
        )
    }

    private var liveAlwaysOnScheduleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnSchedule },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnSchedule(newValue) } }
        )
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

    /// Premium 전용 행 게이트 — 무료 사용자는 컨트롤 조작을 가로채 "Premium" 토스트만 띄운다.
    /// 잠금 표시 없이 평소처럼 보이되, 탭이 컨트롤에 닿기 전에 오버레이가 가로챈다.
    @ViewBuilder
    private func premiumGated(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .overlay {
                if !isPremiumUser {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { toastCenter.show("Premium") }
                }
            }
    }

    private var liveAlwaysOnBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOn },
            set: { newValue in Task { await viewModel.setLiveAlwaysOn(newValue) } }
        )
    }

    /// "캘린더 함께 표시"(true) 선택은 Premium 전용 — 무료면 저장하지 않고 Premium 토스트만.
    /// getter가 계속 false를 돌려주므로 선택은 "기본"에 머문다. "기본"으로 되돌리기는 항상 허용.
    private var memoShowsCalendarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.memoShowsCalendar },
            set: { newValue in
                guard isPremiumUser || !newValue else {
                    toastCenter.show("Premium")
                    return
                }
                Task { await viewModel.setMemoShowsCalendar(newValue) }
            }
        )
    }

    private var scheduleShowsCalendarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.scheduleShowsCalendar },
            set: { newValue in
                guard isPremiumUser || !newValue else {
                    toastCenter.show("Premium")
                    return
                }
                Task { await viewModel.setScheduleShowsCalendar(newValue) }
            }
        )
    }

}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(dependencies: .preview))
    }
}
