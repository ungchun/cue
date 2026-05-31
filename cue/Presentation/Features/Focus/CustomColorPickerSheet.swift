//
//  CustomColorPickerSheet.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// `UIColorPickerViewController`의 SwiftUI 래퍼 — 시스템 컬러 피커를 시트 콘텐츠로.
///
/// `UINavigationController`로 감싸서 nav 바를 직접 통제한다:
/// - 좌상단: 커스텀 X 닫기 버튼 (`onClose` 콜백)
/// - 우상단: 비움 — 시스템 스포이드 버튼이 통상 우측에 붙어 있어 명시적으로 제거
///
/// 사용자가 picker 안에서 색을 정하면 delegate(`didSelect`)가 hex로 환원해 binding에 반영.
struct CustomColorPickerSheet: UIViewControllerRepresentable {
    @Binding var colorHex: String
    /// 좌상단 X 버튼이 호출 — 부모(에디터 시트)가 `showingCustomColorPicker = false`로
    /// 시트를 내린다.
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let picker = UIColorPickerViewController()
        picker.selectedColor = UIColor(Color(hex: colorHex) ?? .gray)
        picker.supportsAlpha = false
        picker.delegate = context.coordinator
        picker.title = "색상"

        // 좌상단 X 닫기 — 시스템이 기본으로 우측에 붙이는 close를 명시적으로 좌측으로 옮긴다.
        picker.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            primaryAction: UIAction { _ in
                context.coordinator.handleClose()
            }
        )
        // 우측의 시스템 추가 버튼(스포이드 포함) 제거 시도.
        picker.navigationItem.rightBarButtonItems = []
        picker.navigationItem.rightBarButtonItem = nil

        let nav = UINavigationController(rootViewController: picker)
        return nav
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {
        // colorHex가 외부에서 바뀌어도 picker에 다시 push할 필요 없음 — 사용자가 이 picker
        // 안에서 직접 조작하는 게 단일 출처.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(colorHex: $colorHex, onClose: onClose)
    }

    final class Coordinator: NSObject, UIColorPickerViewControllerDelegate {
        @Binding var colorHex: String
        let onClose: () -> Void

        init(colorHex: Binding<String>, onClose: @escaping () -> Void) {
            self._colorHex = colorHex
            self.onClose = onClose
        }

        func colorPickerViewController(
            _ viewController: UIColorPickerViewController,
            didSelect color: UIColor,
            continuously: Bool
        ) {
            colorHex = Color(color).hexString
        }

        func handleClose() {
            onClose()
        }
    }
}
