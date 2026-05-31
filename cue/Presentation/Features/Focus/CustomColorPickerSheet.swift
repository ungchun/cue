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
/// 공개 API로 끌 방법이 없어 view tree를 훑어 다음 단서 중 하나라도 잡히면
/// 그 view를 `isHidden = true` 처리한다:
///  1. 클래스명에 스포이드 관련 키워드 (`Eyedropper`/`Sample`/`Picker.*Well` 등)
///  2. UIButton의 accessibility label에 "스포이드" / "eyedrop"
///  3. UIButton 이미지의 SF Symbol 이름이 "eyedropper" 류 (비공개 `name` KVC)
///  4. UIButton 이미지 description에 "eyedropper"
///
/// 비공개 UI 구조 의존이라 iOS 업데이트 시 깨질 수 있다. DEBUG 빌드에선 첫 layout 시
/// 전체 view 계층을 로그로 찍어 어떤 매칭이 필요한지 진단할 수 있다.
private final class EyedropperHidingColorPickerViewController: UIColorPickerViewController {
    private var didLogHierarchy = false

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        hideEyedropperIfPresent(in: view)

        #if DEBUG
        if !didLogHierarchy {
            didLogHierarchy = true
            print("=== [CuePicker] UIColorPickerViewController hierarchy ===")
            dump(view, indent: 0)
            print("=== [CuePicker] end ===")
        }
        #endif
    }

    private func hideEyedropperIfPresent(in view: UIView) {
        for subview in view.subviews {
            if shouldHide(subview) {
                subview.isHidden = true
                continue
            }
            hideEyedropperIfPresent(in: subview)
        }
    }

    /// 한 view가 스포이드의 흔적인지 4가지 단서를 OR로 판단.
    private func shouldHide(_ view: UIView) -> Bool {
        let className = String(describing: type(of: view)).lowercased()
        if className.contains("eyedrop")
            || className.contains("sample")
            || className.contains("colorwell") {
            return true
        }

        guard let button = view as? UIButton else { return false }

        let label = button.accessibilityLabel?.lowercased() ?? ""
        if label.contains("스포이드")
            || label.contains("eyedrop")
            || label.contains("eye drop") {
            return true
        }

        let image = button.image(for: .normal) ?? button.currentImage
        if let image {
            // SF Symbol의 비공개 `name` KVC — 공식 API 없음. AppStore 심사에 걸릴 수 있어
            // 추후 빼야 할 수도 있지만, 디버그/사이드로드 단계에선 가장 확실한 식별 수단.
            if let symbolName = image.value(forKey: "name") as? String,
               symbolName.lowercased().contains("eyedrop") {
                return true
            }
            if "\(image)".lowercased().contains("eyedropper") {
                return true
            }
        }

        return false
    }

    #if DEBUG
    /// 디버그용 — 전체 view tree를 클래스명·frame·라벨·이미지 description과 함께 출력.
    /// 매칭이 빗나가면 이 출력을 보고 정확한 키워드를 찾아 `shouldHide`에 추가한다.
    private func dump(_ view: UIView, indent: Int) {
        let prefix = String(repeating: "  ", count: indent)
        let className = String(describing: type(of: view))
        var details = ""
        if let button = view as? UIButton {
            let label = button.accessibilityLabel ?? ""
            let imageDesc = button.image(for: .normal).map { "\($0)" } ?? ""
            let symbolName = button.image(for: .normal)?.value(forKey: "name") as? String ?? ""
            details = " label='\(label)' image='\(imageDesc)' symbol='\(symbolName)'"
        }
        print("\(prefix)\(className) frame=\(view.frame)\(details)")
        for sub in view.subviews {
            dump(sub, indent: indent + 1)
        }
    }
    #endif
}
