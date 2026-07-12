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
    /// 텍스트 정렬 — 기본 `.natural`(좌측). 메모 화면처럼 가운데 정렬이 필요하면 `.center`.
    /// `.center`라도 텍스트가 2줄을 넘으면 좌측(`.left`)으로 전환된다 — 긴 메모가 가운데
    /// 정렬돼 줄마다 들쭉날쭉해지는 걸 막고 "왼쪽부터 채우는" 형태로.
    var textAlignment: NSTextAlignment = .natural
    /// `true`면 포커스(편집 중)일 때 placeholder를 숨긴다 — 텍스트가 비어도. 기본은 iOS
    /// 표준(첫 글자 입력 전까지 유지)인 `false`.
    var hidesPlaceholderWhenFocused: Bool = false
    /// 설정 시 이 줄 수까지만 높이가 자라고, 넘으면 내부 스크롤된다(nil이면 무한 확장).
    var maxLines: Int? = nil

    var body: some View {
        ZStack(alignment: textAlignment == .center ? .top : .topLeading) {
            if text.isEmpty && !(hidesPlaceholderWhenFocused && isFocused) {
                Text(placeholder)
                    .font(Font(font))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: textAlignment == .center ? .infinity : nil)
                    .multilineTextAlignment(textAlignment == .center ? .center : .leading)
                    .allowsHitTesting(false)
            }
            Representable(
                text: $text,
                isFocused: $isFocused,
                font: font,
                textColor: textColor,
                submitOnReturn: submitOnReturn,
                textAlignment: textAlignment,
                maxLines: maxLines
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
    var textAlignment: NSTextAlignment
    var maxLines: Int?

    func makeUIView(context: Context) -> UITextView {
        let view = AutoFocusTextView()
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.font = font
        view.textColor = textColor
        view.textAlignment = textAlignment
        view.adjustsFontForContentSizeCategory = true
        view.delegate = context.coordinator
        view.text = text
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        // window 부착 즉시(같은 RunLoop tick) becomeFirstResponder하도록 flag set.
        // DispatchQueue.main.async는 다음 tick으로 미뤄져 이전 view dispose와 새 view become
        // 사이가 1 frame 이상 비어 UIKit이 키보드 dismiss animation을 시작한다.
        // `didMoveToWindow`는 UIKit lifecycle hook — view가 window에 추가되는 그 순간에 호출돼
        // 첫 responder transfer가 같은 tick에 일어나 키보드가 안 내려간다.
        view.becomeFirstResponderOnMount = isFocused
        // 키보드 위 "완료"로 dismiss. SwiftUI `.keyboard` toolbar는 UIViewRepresentable
        // 응답자엔 안 붙으므로 UITextView에 inputAccessoryView를 직접 단다.
        view.inputAccessoryView = Self.makeKeyboardAccessory(for: view)
        return view
    }

    /// 키보드 위 액세서리 바 — 오른쪽 정렬 chevron 아이콘으로 키보드를 내린다(앱 전역 동일
    /// 패턴). 기본 44pt보다 높은 60pt로 둬 버튼이 키보드 위로 떠 보이게 한다.
    private static func makeKeyboardAccessory(for textView: UITextView) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 60))
        let done = UIBarButtonItem(
            title: nil,
            image: UIImage(systemName: "keyboard.chevron.compact.down"),
            primaryAction: UIAction { [weak textView] _ in textView?.resignFirstResponder() },
            menu: nil
        )
        toolbar.items = [.flexibleSpace(), done]
        return toolbar
    }

    /// SwiftUI가 제안한 너비에 맞춰 wrap된 높이를 정확히 돌려준다.
    /// 없으면 UITextView가 자기 intrinsicContentSize로 한 줄 너비를 계속 요구해 wrap이 안 된다.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let lineHeight = (uiView.font ?? font).lineHeight

        // 가운데 정렬(.center)이라도 2줄을 넘으면 자연 정렬로 — "글 시작 쪽부터 채우는" 형태.
        // .natural이라 RTL(아랍어 등)에선 오른쪽부터 채운다. 변경됐을 때만 set해 layout 루프를 피한다.
        if textAlignment == .center, lineHeight > 0 {
            let lines = Int((fitting.height / lineHeight).rounded())
            let desired: NSTextAlignment = lines > 2 ? .natural : .center
            if uiView.textAlignment != desired { uiView.textAlignment = desired }
        }

        // maxLines가 있으면 그 높이까지만 자라고 넘으면 내부 스크롤.
        if let maxLines, lineHeight > 0 {
            let maxHeight = ceil(lineHeight * CGFloat(maxLines))
            let exceeded = fitting.height > maxHeight
            if uiView.isScrollEnabled != exceeded { uiView.isScrollEnabled = exceeded }
            if exceeded { return CGSize(width: width, height: maxHeight) }
        }
        return CGSize(width: width, height: fitting.height)
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        if uiView.font != font { uiView.font = font }
        if uiView.textColor != textColor { uiView.textColor = textColor }
        // .center는 줄 수에 따라 sizeThatFits가 center↔left를 관리하므로 여기서 덮지 않는다.
        // 그 외(natural/left)만 base 정렬을 그대로 유지한다.
        if textAlignment != .center, uiView.textAlignment != textAlignment {
            uiView.textAlignment = textAlignment
        }

        // become만 처리(resign은 UIKit transfer에 위임 — 명시 resign이 race 일으킴).
        // closure 안에서 binding 최신 값을 re-read한다 — capture된 stale 값으로 호출하면
        // 외부에서 binding이 false로 바뀐 뒤에도 first responder를 끌어와 버린다.
        let binding = $isFocused
        DispatchQueue.main.async {
            if binding.wrappedValue && !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    /// SwiftUI가 view를 dispose하기 직전 — delegate를 떼어 dispose 과정에서 발생할
    /// `textViewDidEndEditing` callback이 binding(`isFocused`)을 false로 만들지 않게 한다.
    /// 같은 binding을 공유한 새 mount된 GrowingTextView가 이미 first responder를 잡아도
    /// 이전 view의 dispose-시 didEnd가 binding을 false로 set하면 새 view도 같이 resign된다.
    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        uiView.delegate = nil
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: Representable
        init(_ parent: Representable) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            DispatchQueue.main.async {
                self.parent.isFocused = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // 150ms 지연 — 이 사이 view가 dispose되면 `dismantleUIView`가 `delegate = nil`
            // 처리. async 시점 delegate가 self가 아니면 dispose된 것 → binding 건드리지 않음.
            // 사용자가 키보드를 직접 dismiss한 경우엔 view 살아있어 delegate 그대로 → 정상 false.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak textView] in
                guard let self, let textView, textView.delegate === self else { return }
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

/// UITextView subclass — `didMoveToWindow` UIKit lifecycle hook을 통해 window 부착 즉시
/// (`DispatchQueue.main.async`를 거치지 않고 같은 RunLoop tick에) `becomeFirstResponder`를
/// 호출한다. SwiftUI의 view dispose와 새 view mount가 한 turn 안에 일어날 때 이전 view의
/// resign과 새 view의 become을 같은 tick에 묶어 UIKit이 첫 responder transfer로 인식하게 만든다
/// → 키보드가 dismiss/show되지 않고 그대로 유지.
private final class AutoFocusTextView: UITextView {
    var becomeFirstResponderOnMount: Bool = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, becomeFirstResponderOnMount, !isFirstResponder {
            becomeFirstResponder()
        }
    }
}
