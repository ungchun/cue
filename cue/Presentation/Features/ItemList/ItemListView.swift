//
//  ItemListView.swift
//  cue / Presentation
//

import SwiftUI

/// 예시 Feature — 항목 목록 화면. 구조 참고용이며 실제 도메인에 맞춰 교체한다.
struct ItemListView: View {
    @State private var viewModel: ItemListViewModel
    @State private var newItemTitle = ""

    init(dependencies: Dependencies) {
        _viewModel = State(initialValue: ItemListViewModel(dependencies: dependencies))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: Spacing.sm) {
                    TextField("새 항목", text: $newItemTitle)
                    Button("추가", action: addItem)
                        .disabled(isTitleEmpty)
                }
            }

            Section("항목 \(viewModel.items.count)개") {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.title).font(.headline)
                        if !item.note.isEmpty {
                            Text(item.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
        .navigationTitle("cue")
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            await viewModel.load()
        }
        .alert("오류", isPresented: errorBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var isTitleEmpty: Bool {
        newItemTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func addItem() {
        let title = newItemTitle
        newItemTitle = ""
        Task { await viewModel.add(title: title) }
    }

    private func deleteItems(at offsets: IndexSet) {
        let targets = offsets.map { viewModel.items[$0] }
        Task {
            for item in targets {
                await viewModel.delete(item)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ItemListView(dependencies: .preview)
    }
}
