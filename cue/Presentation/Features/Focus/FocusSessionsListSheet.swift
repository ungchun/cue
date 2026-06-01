//
//  FocusSessionsListSheet.swift
//  cue / Presentation
//

import SwiftUI

/// 저장된 세션 프리셋 목록 — 메인 화면 우상단 버튼이 띄우는 시트.
///
/// nav 바 가운데 "세션" inline 타이틀 · 좌상단 X 닫기 · 우상단 + 추가 (모두 시스템 기본 색).
/// 행을 탭하면 그 세션을 선택하고 시트가 닫히며, 우측 "수정"을 누르면 그 세션을 prefill한
/// `FocusSessionEditorSheet`(중간 detent)이 이 시트 *위에* 스택으로 올라온다.
struct FocusSessionsListSheet: View {
    @Bindable var viewModel: FocusViewModel
    @Environment(\.dismiss) private var dismiss

    /// 신규 추가 시트 표시 — + 버튼이 true로 올린다.
    @State private var showingCreate = false
    /// 수정 시트 표시 — 특정 세션을 prefill해 띄운다. nil이면 닫힘.
    @State private var editingSession: FocusSession?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sessions) { session in
                    sessionRow(session)
                }
            }
            .listStyle(.plain)
            .navigationTitle("세션")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("닫기")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("세션 추가")
                }
            }
            .overlay { emptyOverlay }
            // 새 세션 시트가 이 위에 스택으로 — 부모 시트는 닫히지 않는다.
            // 절반(`.medium`) 대신 전체 높이만 — 폼이 길어 절반에선 키보드 올라오면 잘린다.
            .sheet(isPresented: $showingCreate) {
                FocusSessionEditorSheet(mode: .create, viewModel: viewModel)
                    .presentationDetents([.large])
            }
            .sheet(item: $editingSession) { session in
                FocusSessionEditorSheet(mode: .edit(session), viewModel: viewModel)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - 행

    /// 세션 한 줄. 좌측(점 + 제목)은 탭 시 선택, 우측 "수정"은 탭 시 편집 시트.
    /// 두 영역을 분리해 둬야 한쪽이 다른 쪽의 탭을 가로채지 않는다.
    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: Spacing.zero) {
            // 좌측 — 캡슐 + 빈 공간이 선택 탭 영역. 우측 "수정" 버튼과 분리해 둬야 탭 가로채기가 없다.
            HStack(spacing: Spacing.sm) {
                titleCapsule(session.title, colorHex: session.colorHex)
                Spacer(minLength: Spacing.sm)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectSession(id: session.id)
                dismiss()
            }

            Button("수정") {
                editingSession = session
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, Spacing.xs)
        // trailing swipe는 삭제(destructive)로 — '수정'은 행에 가시 버튼이 있어 swipe는
        // 파괴적 액션 전용으로 둔다.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.deleteSession(id: session.id)
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    /// 세션 색의 옅은(opacity 0.18) 캡슐 + 진한 텍스트. EventRow의 캡슐과 같은 패턴 —
    /// hex 파싱 실패 시엔 시스템 회색으로 폴백.
    private func titleCapsule(_ title: String, colorHex: String) -> some View {
        let color = Color(hex: colorHex) ?? Color(.systemGray)
        return Text(title)
            .font(.body.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Capsule().fill(color.opacity(0.18)))
    }

    /// 세션이 한 건도 없을 때 List 위에 띄우는 안내.
    @ViewBuilder
    private var emptyOverlay: some View {
        if viewModel.sessions.isEmpty {
            ContentUnavailableView(
                "저장된 세션이 없어요",
                systemImage: "timer"
            )
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        FocusSessionsListSheet(viewModel: FocusViewModel(dependencies: .preview))
    }
}
