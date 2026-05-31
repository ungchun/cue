//
//  CustomColorPickerSheet.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 커스텀 색을 고를 수 있는 SwiftUI 시트 — HSB 슬라이더 3개로 임의 색을 만든다.
///
/// `UIColorPickerViewController`는 시스템 스포이드(좌상단)를 공식적으로 끌 방법이 없어
/// 사용을 포기. 슬라이더 + 라이브 프리뷰 조합이면 스포이드 없이도 충분히 색을 만들 수 있고,
/// 시트 chrome(우상단 X, 중간 detent 시작)을 자유롭게 통제할 수 있다.
///
/// 슬라이더 변화는 onChange로 즉시 `colorHex`에 반영 — 사용자가 X를 누르기 전부터
/// 메인 화면·행 캡슐이 새 색으로 갱신된다.
struct CustomColorPickerSheet: View {
    @Binding var colorHex: String
    @Environment(\.dismiss) private var dismiss

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1

    /// 슬라이더 3개로부터 합성한 현재 색 — 프리뷰와 슬라이더 tint·hex 동기화 모두에 사용.
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
            .navigationTitle("커스텀 색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
            }
        }
        // 초반 중간 높이로 — 사용자가 더 보고 싶을 때만 드래그해 .large로 키운다.
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
            sliderRow(label: "색조", value: $hue)
            sliderRow(label: "채도", value: $saturation)
            sliderRow(label: "명도", value: $brightness)
        }
    }

    /// 라벨 + 슬라이더 한 줄. 라벨 폭은 한글 두 글자가 들어가도록 xxl(48)로 고정.
    private func sliderRow(label: String, value: Binding<Double>) -> some View {
        HStack(spacing: Spacing.md) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
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
