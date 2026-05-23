//
//  ReminderView.swift
//  cue / Presentation
//

import SwiftUI
import UIKit

/// 할일 탭 화면 — 선택된 리스트의 미완료 항목을 보여주고 완료 토글을 제공한다.
struct ReminderView: View {
    let viewModel: ReminderViewModel

    @State private var newTitle = ""
    @State private var newMemo = ""
    @State private var showingDetail = false
    @FocusState private var focusedField: NewRowField?

    /// 리스트 맨 아래 새 할일 입력 행의 포커스 대상.
    private enum NewRowField { case title, memo }

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
            .sheet(isPresented: $showingDetail) {
                ReminderDetailSheet(title: $newTitle, memo: $newMemo) { dueDate, includesTime in
                    saveNewReminder(dueDate: dueDate, includesTime: includesTime)
                }
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
            ForEach(viewModel.visibleReminders) { reminder in
                reminderRow(reminder)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task { await viewModel.delete(reminder) }
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
            newReminderRow
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(reminder.title)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(.primary)

                if let dueDate = reminder.dueDate {
                    Text(dueDateText(dueDate))
                        .font(AppFont.bodySmall)
                        .foregroundStyle(isOverdue(dueDate) ? Color.red : Color.secondary)
                }
            }
        }
    }

    /// 리스트 맨 아래 새 할일 입력 행 — 제목·메모를 직접 입력한다.
    /// 포커스 시 메모 칸과 ⓘ 버튼이 나타난다. 엔터로 바로 저장하거나, ⓘ로 세부사항 시트를 연다.
    private var newReminderRow: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "circle.dotted")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                TextField("", text: $newTitle)
                    .font(AppFont.bodyLarge)
                    .foregroundStyle(.primary)
                    .focused($focusedField, equals: .title)
                    .onSubmit { submitNewReminder() }

                if focusedField != nil {
                    TextField("메모 추가", text: $newMemo)
                        .font(AppFont.bodySmall)
                        .foregroundStyle(.secondary)
                        .focused($focusedField, equals: .memo)
                        .onSubmit { submitNewReminder() }
                }
            }

            if focusedField != nil {
                Spacer()
                Button {
                    showingDetail = true
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 입력 행에서 키보드 엔터로 저장 — 제목·메모만 담아 추가한다.
    /// 저장 뒤 입력 행을 비우고 제목 칸 포커스를 유지해 연속 입력을 돕는다.
    private func submitNewReminder() {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let memo = newMemo
        clearNewRow()
        focusedField = .title
        Task { await viewModel.add(title: trimmed, notes: memo) }
    }

    /// 세부사항 시트 완료 — 제목·메모·마감일을 담아 추가한다.
    private func saveNewReminder(dueDate: Date?, includesTime: Bool) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let memo = newMemo
        clearNewRow()
        Task {
            await viewModel.add(
                title: trimmed, notes: memo,
                dueDate: dueDate, includesTime: includesTime
            )
        }
    }

    /// 입력 행을 비운다.
    private func clearNewRow() {
        newTitle = ""
        newMemo = ""
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
