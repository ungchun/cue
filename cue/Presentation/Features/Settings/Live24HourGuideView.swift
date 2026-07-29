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
        // 풀 시트로 연다 — 4단계 절차·주석까지 한 번에 보여야 하는 문서형 시트라
        // `.medium`으로 열리면 사용자가 읽기 전에 먼저 시트를 끌어올려야 한다.
        .presentationDetents([.large])
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

    /// 하단 주석 — 맨 위가 무료 사용자용 조건 고지다.
    ///
    /// 고지를 이 블록의 **첫 줄**에 두는 이유는 성격이 같기 때문이다. 셋 다 "따라 하기 전에
    /// 알아둘 것"이고, 형태(`Label`·`.footnote`·`.secondary`)도 같아야 눈이 한 번만 배운다.
    /// 그중 조건이 가장 먼저 걸리는 문턱이라 맨 위에 온다.
    ///
    /// `lock`은 이 시트에서 아직 안 쓰인 글리프다 — `info.circle`(설명)·
    /// `exclamationmark.triangle`(주의)과 뜻이 겹치지 않는다. 윤곽선 계열로 맞춰
    /// `lock.fill`이 아니라 `lock`을 쓴다.
    private var footnotes: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !premiumStore.isPremium {
                Label {
                    Text("Keeping your Live running 24 hours is a Premium feature.")
                } icon: {
                    Image(systemName: "lock")
                }
            }
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
