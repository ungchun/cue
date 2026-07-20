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
    @Environment(\.premiumStore) private var premiumStore

    /// 유료(Premium) 전용 설정 게이트 — 실제 구매 엔타이틀먼트(`PremiumStore`)를 반응형으로 따른다.
    private var isPremiumUser: Bool { premiumStore.isPremium }

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
            // Cue Premium 배너 — 설정 타이틀 바로 아래. 탭하면 페이월 시트. 이미 프리미엄이면 숨긴다.
            if !isPremiumUser {
                Section {
                    PremiumBannerView {
                        showsPremiumSheet = true
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                // 배너 아래 간격은 전역(28)보다 좁게 — 리스트 간격 값이라 28처럼 리터럴(20).
                .listSectionSpacing(20)
            }

            Section {
                Picker("Display Mode", selection: colorSchemeBinding) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Text(scheme.label).tag(scheme)
                    }
                }
                Picker("Start Tab", selection: startTabBinding) {
                    ForEach(Self.startTabOptions) { tab in
                        Text(tab.title).tag(tab.rawValue)
                    }
                }
            } header: {
                sectionHeader("General")
            }

            Section {
                // 켜기는 Premium 전용 — 바인딩 setter가 가로채 Premium 토스트만 띄운다(끄기는 항상 허용).
                Toggle("Always Show Live", isOn: liveAlwaysOnBinding)
                    .tint(.green)
                // 대상 선택 — 평면 메뉴 한 번에 열림. 서브메뉴 펼침이 없어서 메뉴 재배치
                // 점프(iOS가 서브메뉴 확장 시 메뉴를 위로 밀어 올리는 동작)가 원천적으로 없다.
                // 길어지면 메뉴가 내부 스크롤(시스템 표준).
                LabeledContent("Items") {
                    Menu {
                        Toggle("Memo", isOn: liveAlwaysOnMemoBinding)
                        Toggle("Schedule", isOn: liveAlwaysOnScheduleBinding)
                        Section("Tasks") {
                            Picker("Tasks", selection: reminderScopeMenuBinding) {
                                Text("Off").tag("off")
                                Text("Today").tag("today")
                                Text("Scheduled").tag("scheduled")
                                Text("All").tag("all")
                                ForEach(viewModel.reminderLists, id: \.id) { list in
                                    Text(list.title).tag(list.id)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(liveKindsSummary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.footnote.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .menuOrder(.fixed)
                }
                .disabled(!viewModel.settings.liveAlwaysOn)
                Button("Use 24 Hours") {
                    shows24HourSheet = true
                }
                .foregroundStyle(.primary)
            } header: {
                sectionHeader("Live")
            }

            Section {
                Picker("Text Size", selection: memoTextSizeBinding) {
                    ForEach(MemoTextSize.allCases, id: \.self) { size in
                        Text(size.label).tag(size)
                    }
                }
                premiumGated {
                    ColorPicker("Live Background Color", selection: $memoBackgroundColor, supportsOpacity: false)
                }
                premiumGated {
                    ColorPicker("Live Font Color", selection: $memoFontColor, supportsOpacity: false)
                }
                // 켜기는 Premium 전용 — 바인딩 setter가 가로채 Premium 토스트만 띄운다(끄기는 항상 허용).
                Toggle("Show Calendar", isOn: memoShowsCalendarBinding)
                    .tint(.green)
            } header: {
                sectionHeader("Memo")
            }

            Section {
                // 볼 캘린더 선택 — 전용 화면으로 push(체크리스트). 캘린더가 없으면 행 자체를 숨긴다.
                if !viewModel.eventCalendars.isEmpty {
                    NavigationLink {
                        CalendarSelectionView(viewModel: viewModel)
                    } label: {
                        LabeledContent("Calendars", value: calendarsSummary)
                    }
                }
                Toggle("Show Calendar", isOn: scheduleShowsCalendarBinding)
                    .tint(.green)
            } header: {
                sectionHeader("Schedule")
            }

            Section {
                // 볼 목록 선택 — 전용 화면으로 push(체크리스트). 리스트가 없으면 행 자체를 숨긴다.
                // 오늘/예정/전체는 시스템 필터라 항상 표시되며 여기 대상이 아니다.
                if !viewModel.reminderLists.isEmpty {
                    NavigationLink {
                        ReminderListSelectionView(viewModel: viewModel)
                    } label: {
                        LabeledContent("Lists", value: reminderListsSummary)
                    }
                }
                // 할일 탭에 진입했을 때 가장 먼저 보여줄 화면 — 오늘/예정/전체 또는 사용자 리스트.
                Picker("Default View", selection: tasksDefaultScopeBinding) {
                    Text("Today").tag("today")
                    Text("Scheduled").tag("scheduled")
                    Text("All").tag("all")
                    ForEach(viewModel.reminderLists, id: \.id) { list in
                        Text(list.title).tag(list.id)
                    }
                }
                Toggle("Show Calendar", isOn: reminderShowsCalendarBinding)
                    .tint(.green)
            } header: {
                sectionHeader("Tasks")
            }

            Section {
                Toggle("End Sound", isOn: focusEndSoundBinding)
            } header: {
                sectionHeader("Focus")
            }
            // 앱 전역 무채색 tint(.primary)가 다크 모드에서 토글 ON 트랙을 흰색으로 만들어
            // 노브와 구분이 안 된다 — 토글만 시스템 표준(초록)으로 되돌린다.
            .tint(.green)

            Section {
                Button("Leave a Review") {
                    requestReview()
                }
                Link("Send Feedback", destination: SupportLinks.feedbackMailtoURL)
                LabeledContent("Version", value: AppVersionInfo.display)
            } header: {
                sectionHeader("Support")
            }
            // 지원 섹션의 버튼·링크 색(틴트) 제거 — 단색 텍스트로.
            .tint(.primary)
        }
        .listSectionSpacing(28)
        // 타이틀↔배너 간격 — 배너 아래 간격과 같은 20.
        .contentMargins(.top, 20, for: .scrollContent)
        .navigationTitle("Settings")
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


    /// 표시 대상 요약 — 선택된 종류를 행 우측에 보여준다("메모, 할일" / 셋 다면 "전체").
    /// 할일 범위는 병기하지 않는다(서브메뉴 값으로 확인).
    private var liveKindsSummary: String {
        let settings = viewModel.settings
        let selected = [
            settings.liveAlwaysOnMemo ? String(localized: "Memo") : nil,
            settings.liveAlwaysOnReminder ? String(localized: "Tasks") : nil,
            settings.liveAlwaysOnSchedule ? String(localized: "Schedule") : nil,
        ].compactMap(\.self)
        if selected.count == 3 { return String(localized: "All") }
        return selected.joined(separator: ", ")
    }





    private var liveAlwaysOnMemoBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnMemo },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnMemo(newValue) } }
        )
    }

    private var liveAlwaysOnScheduleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOnSchedule },
            set: { newValue in Task { await viewModel.setLiveAlwaysOnSchedule(newValue) } }
        )
    }

    /// 할일 단일 선택 — "off"는 할일 항목 끔, 나머지는 켬 + 범위 지정.
    private var reminderScopeMenuBinding: Binding<String> {
        Binding(
            get: {
                viewModel.settings.liveAlwaysOnReminder
                    ? viewModel.settings.liveAlwaysOnReminderScopeID
                    : "off"
            },
            set: { newValue in
                Task {
                    if newValue == "off" {
                        await viewModel.setLiveAlwaysOnReminder(false)
                    } else {
                        await viewModel.setLiveAlwaysOnReminder(true)
                        await viewModel.setLiveAlwaysOnReminderScopeID(newValue)
                    }
                }
            }
        )
    }

    /// 섹션 헤더 — 기본보다 작은 글자.
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.body.weight(.medium))
    }

    /// 섹션 풋터 설명 — 기본보다 작은 글자.
    private func sectionFooter(_ text: LocalizedStringKey) -> some View {
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

    /// 볼 캘린더 요약 — 전부 표시면 "All"(정상 상태), 일부 숨김이면 숨긴 개수만 강조("N Hidden").
    /// 비율("18/20")은 사용자가 뺄셈을 해야 하므로, 기본값에서 벗어난 만큼만 보여준다.
    private var calendarsSummary: String {
        let hidden = viewModel.eventCalendars.filter {
            viewModel.settings.hiddenCalendarIDs.contains($0.id)
        }.count
        if hidden == 0 { return String(localized: "All") }
        return String(localized: "\(hidden) Hidden")
    }

    /// 볼 목록 요약 — 전부 표시면 "All", 일부 숨김이면 숨긴 개수("N Hidden"). 캘린더 요약과 동일.
    private var reminderListsSummary: String {
        let hidden = viewModel.reminderLists.filter {
            viewModel.settings.hiddenReminderListIDs.contains($0.id)
        }.count
        if hidden == 0 { return String(localized: "All") }
        return String(localized: "\(hidden) Hidden")
    }

    /// 할일 탭 기본 화면 스코프("today"/"scheduled"/"all"/리스트 id).
    private var tasksDefaultScopeBinding: Binding<String> {
        Binding(
            get: { viewModel.settings.tasksDefaultScopeID },
            set: { newValue in Task { await viewModel.setTasksDefaultScopeID(newValue) } }
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
            // 컨트롤 자체를 비활성화해 확실히 막고(스와치 탭 포함), 탭은 오버레이가 받아 토스트만.
            .disabled(!isPremiumUser)
            .overlay {
                if !isPremiumUser {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { toastCenter.show("Premium") }
                }
            }
    }

    /// "항상 표시" 켜기는 Premium 전용 — 무료면 저장하지 않고 Premium 토스트만. 끄기는 항상 허용.
    private var liveAlwaysOnBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.liveAlwaysOn },
            set: { newValue in
                guard isPremiumUser || !newValue else {
                    toastCenter.show("Premium")
                    return
                }
                Task { await viewModel.setLiveAlwaysOn(newValue) }
            }
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

    private var reminderShowsCalendarBinding: Binding<Bool> {
        Binding(
            get: { viewModel.settings.reminderShowsCalendar },
            set: { newValue in
                guard isPremiumUser || !newValue else {
                    toastCenter.show("Premium")
                    return
                }
                Task { await viewModel.setReminderShowsCalendar(newValue) }
            }
        )
    }

}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel(dependencies: .preview))
    }
}
