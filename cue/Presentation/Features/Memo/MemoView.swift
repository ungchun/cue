//
//  MemoView.swift
//  cue / Presentation
//

import SwiftUI

/// 메모 탭 화면 — 가운데 큰 텍스트 입력. 좌상단 설정 버튼만 둔다.
///
/// 입력한 텍스트는 변경 즉시 저장된다. (색 선택·라이브 액티비티 토글 진입점은 제거됨 —
/// 관련 동작은 `MemoViewModel`에 남아 있어 추후 다른 UI에 다시 붙일 수 있다.)
struct MemoView: View {
    @Bindable var viewModel: MemoViewModel

    var body: some View {
        VStack(spacing: Spacing.zero) {
            Spacer()
            TextField("메모를 입력하세요", text: textBinding, axis: .vertical)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.onAppear()
        }
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
