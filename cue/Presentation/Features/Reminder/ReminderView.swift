//
//  ReminderView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 할일 탭 화면 — 선택된 리스트의 미완료 항목을 보여주고 완료 토글을 제공한다.
struct ReminderView: View {
    let viewModel: ReminderViewModel

    var body: some View {
        content
            .navigationTitle("할일")
            .toolbar {
                // 뷰만 — 액션은 아직 없음.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
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
            if viewModel.visibleReminders.isEmpty {
                Text("할 일이 없습니다.")
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                ForEach(viewModel.visibleReminders) { reminder in
                    reminderRow(reminder)
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
            }
        }
    }

    /// 미리알림 한 줄 — 동그란 체크 버튼 + 제목, 마감일이 있으면 그 아래 표시.
    private func reminderRow(_ reminder: Reminder) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Button {
                Task { await viewModel.toggle(reminder) }
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reminder.title)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(AppColor.textPrimary)

                if let dueDate = reminder.dueDate {
                    Text(dueDateText(dueDate))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(isOverdue(dueDate) ? AppColor.danger : AppColor.textSecondary)
                }
            }
        }
    }

    /// 마감일 표시 문자열 — 오늘·내일은 단어로, 그 외엔 날짜로.
    private func dueDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return "오늘 \(time)"
        } else if calendar.isDateInTomorrow(date) {
            return "내일 \(time)"
        } else {
            return date.formatted(date: .numeric, time: .shortened)
        }
    }

    /// 마감일이 현재 시각보다 지났으면 true — 지난 항목은 빨갛게 표시한다.
    private func isOverdue(_ date: Date) -> Bool {
        date < .now
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

#Preview {
    NavigationStack {
        ReminderView(viewModel: ReminderViewModel(dependencies: .preview))
    }
}
