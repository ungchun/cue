//
//  Live24HourGuideView.swift
//  cue / Presentation
//
//  설정 > 라이브 > "24시간 사용하기" 시트 — 라이브 액티비티는 시스템이 8시간 후 종료하므로,
//  단축어 앱의 자동화(매일 8시간 간격 3회)로 '라이브 새로고침'을 실행해 중단 없이 유지하는
//  방법을 안내한다. 상단 버튼으로 단축어 앱에 바로 랜딩한다.
//

import SwiftUI

struct Live24HourGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dependencies) private var dependencies
    @Environment(\.premiumStore) private var premiumStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    if !premiumStore.isPremium {
                        premiumNotice
                    }
                    shortcutsButton
                    steps
                    Divider()
                    footnotes
                }
                .padding(Spacing.md)
            }
            .navigationTitle("Use 24 Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.smd) {
            Image(systemName: "clock.arrow.2.circlepath")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Use the Shortcuts app’s ‘Automation’ to keep your Live running without interruption.")
                .font(.headline)
        }
    }

    /// 무료 사용자에게만 보이는 조건 고지 — 자동화를 만들기 **전에** 읽혀야 헛수고가 없다.
    ///
    /// 하단 주석과 같은 `.footnote`·`.secondary`로 두고 아이콘도 붙이지 않는다. 자물쇠나
    /// 큰 배너를 쓰면 시트를 여는 순간 "차단됨"으로 읽혀, 이 시트 본래의 목적(기능 설명)보다
    /// 잠금이 먼저 말을 건다. 조건이지 거부가 아니다.
    ///
    /// 「전용」이 아니라 「기능」이라 쓴다 — 정보량은 같고 배제의 어감만 뺀다.
    /// 표기는 `Cue Premium`이 아니라 `Premium` — 브랜드 타이틀 자리(배너·페이월 제목)가
    /// 아닌 곳의 언급은 전부 `Premium`이다(`ToastCenter.showPremium` 전례).
    private var premiumNotice: some View {
        Text("Keeping your Live running 24 hours is a Premium feature.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            // 바깥 VStack의 `Spacing.lg`는 문단 사이 간격이라 한 줄짜리 주석에는 과하다 —
            // 위아래로 `Spacing.sm`씩 당겨 24 → 16으로 좁힌다. 스택 간격을 통째로 줄이면
            // 프리미엄 사용자(이 줄이 없는 화면)의 여백까지 같이 바뀐다.
            .padding(.vertical, -Spacing.sm)
    }

    /// 단축어 앱 랜딩 — 탭하면 바로 단축어 앱이 열린다(자동화 탭으로 이동해 설정).
    /// 앞의 아이콘은 실제 단축어 앱 아이콘 에셋.
    private var shortcutsButton: some View {
        Button {
            dependencies.analytics.log(.externalAppOpened(app: "shortcuts"))
            openURL(URL(string: "shortcuts://")!)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image("ShortcutsAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Spacing.lg, height: Spacing.lg)
                Text("Open Shortcuts")
                    .font(.body.weight(.semibold))
                    // tint(.primary) 캡슐은 다크에서 흰 배경 — 라벨 기본 흰색이 묻히므로
                    // 배경 반전색으로 명시(페이월 CTA와 같은 관용구).
                    .foregroundStyle(Color(.systemBackground))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.primary)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            stepRow(1, "Go to the ‘Automation’ tab in the Shortcuts app and create a new automation.")
            stepRow(2, "Under ‘Time of Day’, choose ‘Daily’ and ‘Run Immediately’.")
            stepRow(3, "Select Cue’s ‘Refresh Live’ from the list.")
            stepRow(4, "Repeat twice more to create three automations running 8 hours apart. e.g. 00:00, 08:00, 16:00")
        }
    }

    private func stepRow(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(number).")
                .font(.body.weight(.semibold))
                .monospacedDigit()
            Text(text)
                .font(.body)
        }
    }

    private var footnotes: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label {
                Text("Live Activities are automatically ended by the system after 8 hours — the automation turns them back on every 8 hours.")
            } icon: {
                Image(systemName: "info.circle")
            }
            Label {
                Text("If run times overlap with other automations, they may not run at the same time. Space them apart. e.g. 00:01, 08:01, 16:01")
            } icon: {
                Image(systemName: "exclamationmark.triangle")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    Live24HourGuideView()
}
