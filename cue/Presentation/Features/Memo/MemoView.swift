//
//  MemoView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 메모 탭 화면 — 가운데 큰 텍스트 입력. 좌상단 설정 버튼만 둔다.
///
/// 입력한 텍스트는 변경 즉시 저장된다. (색 선택·라이브 액티비티 토글 진입점은 제거됨 —
/// 관련 동작은 `MemoViewModel`에 남아 있어 추후 다른 UI에 다시 붙일 수 있다.)
///
/// 입력은 `GrowingTextView`(UIKit) — SwiftUI `TextField`의 `.toolbar(placement: .keyboard)`가
/// 탭 안 화면에선 키보드 위 "완료" 버튼을 띄우지 못해, UITextView `inputAccessoryView`로
/// 확실히 dismiss 버튼이 붙는 컴포넌트를 쓴다.
struct MemoView: View {
    @Bindable var viewModel: MemoViewModel
    @State private var inputFocused = false

    var body: some View {
        VStack(spacing: Spacing.zero) {
            Spacer()
            GrowingTextView(
                text: textBinding,
                isFocused: $inputFocused,
                placeholder: "메모를 입력하세요",
                font: Self.memoFont,
                textColor: .label,
                textAlignment: .center
            )
            .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = true }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.onAppear()
        }
    }

    /// 큰 제목 굵게(`largeTitle` + bold) — Dynamic Type 텍스트 스타일 기반 UIFont.
    private static var memoFont: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .largeTitle)
        let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) ?? base.fontDescriptor
        return UIFont(descriptor: descriptor, size: 0)
    }

    /// 텍스트 바인딩 — 변경 시 ViewModel을 통해 저장 + (LA 활성 시) 반영.
    private var textBinding: Binding<String> {
        Binding(
            get: { viewModel.memo.text },
            set: { newValue in Task { await viewModel.setText(newValue) } }
        )
    }
}

#Preview {
    NavigationStack {
        MemoView(viewModel: MemoViewModel(dependencies: .preview))
    }
}
