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
            .navigationTitle("24시간 사용하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
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
            Text("단축어 앱의 ‘자동화’를 이용하면 라이브를 중단 없이 사용할 수 있어요.")
                .font(.headline)
        }
    }

    /// 단축어 앱 랜딩 — 탭하면 바로 단축어 앱이 열린다(자동화 탭으로 이동해 설정).
    /// 앞의 아이콘은 실제 단축어 앱 아이콘 에셋.
    private var shortcutsButton: some View {
        Button {
            openURL(URL(string: "shortcuts://")!)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image("ShortcutsAppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Spacing.xl, height: Spacing.xl)
                Text("단축어 열기")
                    .font(.body.weight(.semibold))
            }
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(.primary)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Spacing.smd) {
            stepRow(1, "단축어 앱의 ‘자동화’ 탭으로 이동하여 새로운 자동화를 생성합니다.")
            stepRow(2, "‘특정 시간’에서 ‘매일’, ‘즉시 실행’을 선택합니다.")
            stepRow(3, "목록에서 Cue의 ‘라이브 새로고침’을 선택합니다.")
            stepRow(4, "같은 과정을 두 번 더 반복하여 8시간 간격으로 실행되는 3개의 자동화를 만듭니다. 예) 00:00, 08:00, 16:00")
        }
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
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
                Text("라이브 액티비티는 시스템 정책상 8시간이 지나면 자동으로 종료됩니다 — 자동화가 8시간마다 다시 켜줍니다.")
            } icon: {
                Image(systemName: "info.circle")
            }
            Label {
                Text("다른 자동화와 실행 시각이 겹치면 동시에 실행되지 않을 수 있어요. 시간을 분리해 설정하세요. 예) 00:01, 08:01, 16:01")
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
