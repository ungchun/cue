//
//  GrowingTextView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 멀티라인 자동 확장 텍스트 입력 — UIKit `UITextView` 기반 SwiftUI 컴포넌트.
///
/// **왜 자체 컴포넌트인가**:
/// SwiftUI `TextField(axis: .vertical)`는 내부 `UITextView`의 `textContainerInset.top`(시스템 기본 8pt)을
/// SwiftUI 측에서 제어할 수 없어, leading SF Symbol 아이콘과 첫 줄 텍스트를 픽셀 단위로 정렬하기가 사실상
/// 불가능하다. 이 컴포넌트는 `textContainerInset = .zero` + `textContainer.lineFragmentPadding = 0`으로
/// 자체 padding을 모두 0으로 만들어 `HStack(alignment: .top)` 안에서 아이콘과 첫 줄이 정확히 정렬된다.
///
/// **자동 확장**: `isScrollEnabled = false` + content hugging priority `.required`로 컨텐츠 크기에 맞춰
/// 세로로 자연스럽게 확장. SwiftUI 레이아웃이 자체 크기 계산.
///
/// **Placeholder**: `UITextView`는 placeholder 미지원 → SwiftUI `Text` overlay로 처리. 텍스트가 비었을
/// 때만 보이고 입력은 받지 않는다(`allowsHitTesting(false)`).
///
/// **Focus**: SwiftUI `@FocusState`는 `UIViewRepresentable`과 직접 연결되지 않으므로 `@Binding<Bool>`로
/// 양방향 동기화. 외부에서 `isFocused = true`로 바꾸면 `becomeFirstResponder`, UIKit이 begin/end
/// editing할 때 `isFocused`를 역으로 갱신한다.
struct GrowingTextView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = ""
    var font: UIFont
    var textColor: UIColor
    /// `true`면 Return 키 입력 시 줄바꿈 대신 `resignFirstResponder`를 호출 — 외부 commit 흐름이
    /// focus 해제 onChange를 받아 저장한다. `false`면 기본 UITextView 동작(줄바꿈).
    var submitOnReturn: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            Representable(
                text: $text,
                isFocused: $isFocused,
                font: font,
                textColor: textColor,
                submitOnReturn: submitOnReturn
            )
        }
        // UIViewRepresentable은 SwiftUI에 firstTextBaseline을 보고하지 않으므로 직접 명시 —
        // textContainerInset = 0이라 frame top에서 글자 baseline까지 거리 = `font.ascender`.
        // 이걸로 `HStack(alignment: .firstTextBaseline)` 안에서 leading SF Symbol과 자연스럽게 정렬된다.
        .alignmentGuide(.firstTextBaseline) { _ in font.ascender }
    }
}

private struct Representable: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var font: UIFont
    var textColor: UIColor
    var submitOnReturn: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.font = font
        view.textColor = textColor
        view.adjustsFontForContentSizeCategory = true
        view.delegate = context.coordinator
        view.text = text
        // 세로는 컨텐츠만큼 강하게 잡고(자동 확장), 가로는 .defaultLow로 풀어 SwiftUI 부모가
        // 제안한 너비에 wrap되도록 한다 — 기본 `.defaultHigh`면 한 줄로 width를 계속 늘려서
        // 줄바꿈이 안 일어난다.
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    /// SwiftUI가 제안한 너비에 맞춰 wrap된 높이를 정확히 돌려준다.
    /// 없으면 UITextView가 자기 intrinsicContentSize로 한 줄 너비를 계속 요구해 wrap이 안 된다.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: fitting.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.font != font { uiView.font = font }
        if uiView.textColor != textColor { uiView.textColor = textColor }

        // 외부에서 isFocused가 바뀌면 firstResponder 상태를 동기화 — 이미 일치하면 noop.
        let shouldFocus = isFocused
        DispatchQueue.main.async {
            if shouldFocus && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            } else if !shouldFocus && uiView.isFirstResponder {
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: Representable
        init(_ parent: Representable) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // SwiftUI 업데이트 중에 binding을 바꾸면 경고가 나므로 다음 runloop tick으로 미룬다.
            DispatchQueue.main.async {
                self.parent.isFocused = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.isFocused = false
            }
        }

        /// Return 키를 줄바꿈으로 두지 않고 commit 트리거로 쓰려면, 입력을 막고 firstResponder를 푼다.
        /// 외부 onChange(isFocused)가 commit 흐름을 받는다.
        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            if parent.submitOnReturn && text == "\n" {
                textView.resignFirstResponder()
                return false
            }
            return true
        }
    }
}
