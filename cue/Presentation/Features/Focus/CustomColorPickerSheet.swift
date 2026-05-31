//
//  CustomColorPickerSheet.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// `UIColorPickerViewController`의 SwiftUI 래퍼 — 시트로 띄워 임의 색을 고르게 한다.
///
/// SwiftUI의 `ColorPicker`는 자체 swatch UI(작은 시스템 원)를 항상 그리고 프로그램으로 열 수
/// 있는 API를 제공하지 않는다. 무지개 슬롯을 탭하면 system color picker를 즉시 띄우려면
/// UIKit picker를 직접 wrap해 시트 콘텐츠로 사용하는 게 가장 깔끔하다.
///
/// 선택 콜백은 `didSelect ... continuously`만 구독 — 사용자가 색을 한 번 정할 때마다 hex로
/// 환원되어 binding에 반영된다(슬라이더 드래그 중 연속 호출 포함).
struct CustomColorPickerSheet: UIViewControllerRepresentable {
    @Binding var colorHex: String

    func makeUIViewController(context: Context) -> UIColorPickerViewController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(Color(hex: colorHex) ?? .gray)
        picker.supportsAlpha = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIColorPickerViewController, context: Context) {
        // 외부에서 colorHex가 바뀌어도 picker 안에 다시 push할 필요 없음 — 사용자가 이 picker
        // 안에서 직접 조작하는 게 단일 출처.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(colorHex: $colorHex)
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        @Binding var colorHex: String

        init(colorHex: Binding<String>) {
            self._colorHex = colorHex
        }

        func colorPickerViewController(
            _ viewController: UIColorPickerViewController,
            didSelect color: UIColor,
            continuously: Bool
        ) {
            colorHex = Color(color).hexString
        }
    }
}
