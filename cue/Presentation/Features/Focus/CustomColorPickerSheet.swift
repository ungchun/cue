//
//  CustomColorPickerSheet.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 시스템 컬러 피커(`UIColorPickerViewController`)를 시트로 띄우는 SwiftUI 래퍼.
///
/// 외곽에 UINavigationController를 씌우면 시스템 picker가 자체 헤더("색상" + 스포이드)를
/// 또 하나 그려 두 줄이 겹친다. 대신 picker를 그대로 띄우고 좌상단에 SwiftUI Button overlay로
/// X 닫기를 띄운다 — 헤더는 picker의 내부 것 하나로 통일.
///
/// 좌측 스포이드 버튼은 picker 서브클래스에서 view tree를 훑어 accessibility label로
/// 식별해 hidden 처리. 비공개 레이아웃에 의존하므로 iOS 업데이트로 깨질 수 있다.
struct CustomColorPickerSheet: View {
    @Binding var colorHex: String
    /// 좌상단 X 버튼이 호출 — 부모(에디터 시트)가 `showingCustomColorPicker = false`로
    /// 시트를 내린다.
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ColorPickerRepresentable(colorHex: $colorHex)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .accessibilityLabel("닫기")
        }
    }
}

/// `UIColorPickerViewController`를 그대로 노출하는 representable. 헤더는 picker 자체의
/// 것을 사용 — 별도 nav 바 없음.
private struct ColorPickerRepresentable: UIViewControllerRepresentable {
    @Binding var colorHex: String

    func makeUIViewController(context: Context) -> EyedropperHidingColorPickerViewController {
        let picker = EyedropperHidingColorPickerViewController()
        picker.selectedColor = UIColor(Color(hex: colorHex) ?? .gray)
        picker.supportsAlpha = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ controller: EyedropperHidingColorPickerViewController, context: Context
    ) {
        // 단방향 — picker 내부에서 사용자가 조작하는 게 단일 출처.
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

/// `UIColorPickerViewController` 서브클래스 — 좌상단 스포이드 버튼을 숨긴다.
///
/// 시스템이 제공하는 공개 API로는 스포이드를 끌 수 없어 view tree를 훑어 accessibility
/// label이 "스포이드"·"eyedropper"인 UIButton을 찾아 `isHidden = true`로 설정한다.
/// 비공개 UI 구조에 의존하는 hack이라 iOS 업데이트 시 깨질 수 있음.
private final class EyedropperHidingColorPickerViewController: UIColorPickerViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hideEyedropperIfPresent(in: view)
    }

    private func hideEyedropperIfPresent(in view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                let label = button.accessibilityLabel?.lowercased() ?? ""
                if label.contains("스포이드")
                    || label.contains("eyedrop")
                    || label.contains("eye drop") {
                    button.isHidden = true
                    continue
                }
            }
            hideEyedropperIfPresent(in: subview)
        }
    }
}
