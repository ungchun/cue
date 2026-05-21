//
//  ReminderView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 미리알림 탭 화면 — 선택된 리스트의 항목을 보여주고 추가·완료 토글을 제공한다.
///
/// 리스트 선택 칩은 탭바 위 `ReminderListBar` 액세서리가 담당한다.
struct ReminderView: View {
    let viewModel: ReminderViewModel
    @State private var newReminderTitle = ""

    var body: some View {
        content
            .navigationTitle(viewModel.selectedList?.title ?? "미리알림")
            .task { await viewModel.onAppear() }
            .alert("오류", isPresented: errorBinding) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.access {
        case .notDetermined:
            ProgressView()
        case .denied:
            deniedView
        case .granted:
            reminderList
        }
    }

    private var deniedView: some View {
        ContentUnavailableView {
            Label("미리 알림 접근 필요", systemImage: "lock")
        } description: {
            Text("설정에서 cue의 미리 알림 접근을 허용해 주세요.")
        } actions: {
            Button("설정 열기") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var reminderList: some View {
        List {
            Section {
                HStack(spacing: Spacing.sm) {
                    TextField("새 미리알림", text: $newReminderTitle)
                        .onSubmit(addReminder)
                    Button("추가", action: addReminder)
                        .disabled(isTitleEmpty)
                }
            }

            Section {
                if viewModel.visibleReminders.isEmpty {
                    Text("이 리스트에 미리알림이 없습니다.")
                        .font(AppFont.bodyLarge)
                        .foregroundStyle(AppColor.textSecondary)
                } else {
                    ForEach(viewModel.visibleReminders) { reminder in
                        reminderRow(reminder)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(spacing: Spacing.sm) {
            Button {
                Task { await viewModel.toggle(reminder) }
            } label: {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        reminder.isCompleted ? AppColor.accent : AppColor.textSecondary
                    )
            }
            .buttonStyle(.plain)

            Text(reminder.title)
                .font(AppFont.bodyLarge)
                .foregroundStyle(
                    reminder.isCompleted ? AppColor.textSecondary : AppColor.textPrimary
                )
                .strikethrough(reminder.isCompleted)
        }
    }

    private var isTitleEmpty: Bool {
        newReminderTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func addReminder() {
        guard !isTitleEmpty else { return }
        let title = newReminderTitle
        newReminderTitle = ""
        Task { await viewModel.add(title: title) }
    }
}

#Preview {
    NavigationStack {
        ReminderView(viewModel: ReminderViewModel(dependencies: .preview))
    }
}
