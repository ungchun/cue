//
//  MemoView.swift
//  cue / Presentation
//

import StoreKit
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
    /// 앱 공통 토스트 — "켜기"로 라이브가 켜지면 상단 토스트를 띄운다.
    @Environment(\.toastCenter) private var toastCenter
    @Environment(\.dependencies) private var dependencies
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        VStack(spacing: Spacing.zero) {
            Spacer()
            VStack(spacing: Spacing.lg) {
                // 아래 라이브 버튼 줄과 같은 높이의 균형용 미러 — 버튼 줄이 블록에 포함돼
                // 텍스트가 화면 중앙보다 위로 밀리는 것을 상쇄해, 입력+밑줄이 정중앙에 온다.
                liveButtonRow.hidden()
                HStack(spacing: Spacing.sm) {
                    // 좌측 균형용 빈 칸 — 우측 x 버튼과 같은 폭(같은 글래스 버튼을 hidden)으로
                    // 비워 텍스트가 화면 가운데 정렬되게.
                    clearButton.hidden()
                    GrowingTextView(
                        text: textBinding,
                        isFocused: $inputFocused,
                        placeholder: String(localized: "What to remember?"),
                        font: memoFont,
                        textColor: .label,
                        textAlignment: .center,
                        hidesPlaceholderWhenFocused: true,
                        maxLines: 5,
                        maxLength: MemoViewModel.maxTextLength
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
                liveButtonRow
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

    /// 밑줄 아래 라이브 켜기 버튼 줄 — 균형용 미러(hidden)와 실제 줄이 공유한다.
    private var liveButtonRow: some View {
        HStack {
            Spacer()
            FloatingMessageButton {
                let wasActive = viewModel.liveActivityActive
                let verdict = await viewModel.toggleLiveActivity()
                // 실제로 게시된 경우만 리뷰 후보 — .denied는 기존 LA를 건드리지 않아
                // liveActivityActive가 true로 남을 수 있으므로 분기에서 직접 구분한다.
                var published = false
                switch verdict {
                case .unlimited where viewModel.liveActivityActive:
                    toastCenter.show(wasActive ? String(localized: "Refreshed") : String(localized: "Live"))
                    published = true
                case .denied:
                    toastCenter.showPremium()
                case .allowed(let remaining, let limit) where viewModel.liveActivityActive:
                    // 무료 한도 잔여 표기 — "1/2" → "0/2".
                    toastCenter.show("\(remaining) / \(limit)")
                    published = true
                default:
                    break
                }
                if published, await dependencies.considerReviewPrompt() {
                    dependencies.analytics.log(.reviewRequested(source: "live"))
                    requestReview()
                }
            }
            .disabled(!hasText)
        }
    }

    /// 설정 글자 크기에 맞춘 굵은 제목 글꼴 — 텍스트 스타일 기반 UIFont(Dynamic Type 반영).
    /// LA·미리보기 기준(`MemoTextMetrics.textOnlyBase` = 34)이 여기 "크게"(`.largeTitle`)에
    /// 맞춰져 있다 — 설정의 "작게/보통/크게"가 세 화면에서 한 가지 크기를 뜻하게 하기 위함.
    private var memoFont: UIFont {
        let base = UIFont.preferredFont(forTextStyle: viewModel.textSize.inputTextStyle)
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
        .accessibilityLabel("Clear")
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
