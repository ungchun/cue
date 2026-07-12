//
//  CustomColorPickerSheet.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 임의 색을 고르는 SwiftUI 시트 — 색상 프리뷰 + HSB(색조·채도·명도) 슬라이더 3개.
///
/// iOS 17+에서 `UIColorPickerViewController`는 별도 scene(다른 프로세스)에서 렌더돼
/// 시스템 스포이드 버튼을 hide할 수 없다. system picker를 포기하고 SwiftUI 네이티브로
/// 다시 짠다 — chrome(좌상단 X, .medium 초기 detent)을 완전히 통제.
///
/// 슬라이더 변화는 onChange로 즉시 `colorHex`에 반영 — 사용자가 X를 누르기 전부터
/// 메인 화면·행 캡슐이 새 색으로 갱신된다.
struct CustomColorPickerSheet: View {
    @Binding var colorHex: String
    /// 좌상단 X 버튼이 호출 — 부모(에디터 시트)가 `showingCustomColorPicker = false`로
    /// 시트를 내린다.
    let onClose: () -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1

    /// 슬라이더 3개로부터 합성한 현재 색 — 프리뷰·슬라이더 tint·hex 동기화 모두에 사용.
    private var currentColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                preview
                slidersGroup
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .navigationTitle("Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        // 중간 detent로 초기 표시 — 사용자가 드래그해 풀 시트로 확장 가능.
        .presentationDetents([.medium, .large])
        .onAppear { syncFromHex() }
        .onChange(of: hue) { _, _ in syncToHex() }
        .onChange(of: saturation) { _, _ in syncToHex() }
        .onChange(of: brightness) { _, _ in syncToHex() }
    }

    // MARK: - 프리뷰 + 슬라이더

    /// 현재 색의 큼직한 미리보기 — 라운드 사각형.
    private var preview: some View {
        RoundedRectangle(cornerRadius: Spacing.md)
            .fill(currentColor)
            .frame(height: Spacing.xxl * 2)
    }

    /// 색조·채도·명도 슬라이더 3종 묶음.
    private var slidersGroup: some View {
        VStack(spacing: Spacing.md) {
            sliderRow(label: "Hue", value: $hue)
            sliderRow(label: "Saturation", value: $saturation)
            sliderRow(label: "Brightness", value: $brightness)
        }
    }

    /// 라벨 + 슬라이더 한 줄. 라벨 폭은 한글 두 글자가 들어가도록 xxl(48)로 고정.
    /// 슬라이더 tint를 currentColor로 두어 라이브 시각 피드백.
    private func sliderRow(label: LocalizedStringKey, value: Binding<Double>) -> some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: Spacing.xxl, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(currentColor)
        }
    }

    // MARK: - hex ↔ HSB 동기화

    /// 시트 첫 표시 시 부모의 hex를 HSB로 풀어 슬라이더 초기 위치를 잡는다.
    /// SwiftUI Color는 HSB 컴포넌트 getter가 없어 UIColor 경유.
    private func syncFromHex() {
        guard let color = Color(hex: colorHex) else { return }
        let uiColor = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h)
        saturation = Double(s)
        brightness = Double(b)
    }

    /// 슬라이더가 움직일 때마다 호출 — 합성색을 hex로 환원해 부모 binding에 전달.
    private func syncToHex() {
        colorHex = currentColor.hexString
    }
}
