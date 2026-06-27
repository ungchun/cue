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
            VStack(spacing: Spacing.lg) {
                HStack(spacing: Spacing.sm) {
                    // 좌측 균형용 빈 칸 — 우측 x 버튼과 같은 폭(같은 글래스 버튼을 hidden)으로
                    // 비워 텍스트가 화면 가운데 정렬되게.
                    clearButton.hidden()
                    GrowingTextView(
                        text: textBinding,
                        isFocused: $inputFocused,
                        placeholder: "무엇을 기억할까요?",
                        font: Self.memoFont,
                        textColor: .label,
                        textAlignment: .center,
                        hidesPlaceholderWhenFocused: true
                    )
                    // 텍스트 필드 오른쪽 끝의 지우기(x) — 입력 있을 때만 보이되, 빈 칸은 항상
                    // 차지해 레이아웃이 흔들리지 않게(opacity로만 토글).
                    clearButton
                        .opacity(hasText ? 1 : 0)
                        .disabled(!hasText)
                }
                // 입력 공간임을 알리는 밑줄 — 비었을 땐 옅게, 한 글자라도 적히면 primary로.
                Rectangle()
                    .fill(hasText ? Color.primary : Color.primary.opacity(0.3))
                    .frame(height: 1)
                    .animation(.easeInOut(duration: 0.2), value: hasText)

                // 밑줄 아래 — 켜기(우). 입력 있을 때만 활성.
                HStack {
                    Spacer()
                    FloatingMessageButton {
                        await viewModel.toggleLiveActivity()
                    }
                    .disabled(!hasText)
                }
            }
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

    /// 메모에 글자가 한 자라도 있는지 — 밑줄 색·지우기 버튼 표시 기준.
    private var hasText: Bool {
        !viewModel.memo.text.isEmpty
    }

    /// 텍스트 필드 오른쪽 끝의 지우기(x) — iOS 26 Liquid Glass 원형 버튼.
    private var clearButton: some View {
        Button {
            Task { await viewModel.setText("") }
        } label: {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("지우기")
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
