//
//  ReminderListSelectionView.swift
//  cue / Presentation
//

import SwiftUI

/// 할일 탭에 표시할 미리알림 리스트를 고르는 전용 화면 — 설정 > 할일 > 목록에서 push된다.
/// 캘린더 선택 화면(`CalendarSelectionView`)과 같은 형태: 색점 + 이름 + 체크마크 목록.
/// 행을 탭하면 그 자리에서 표시/숨김이 토글되고 화면은 유지된다(뒤로가기로 닫힘).
/// 오늘/예정/전체 시스템 필터는 여기 대상이 아니다 — 항상 표시되며 숨길 수 없다.
struct ReminderListSelectionView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.reminderLists) { list in
                Button {
                    let isVisible = !viewModel.settings.hiddenReminderListIDs.contains(list.id)
                    Task { await viewModel.setReminderListVisible(list.id, !isVisible) }
                } label: {
                    row(for: list)
                }
                .buttonStyle(.plain)
            }
        }
        .contentMargins(.top, Spacing.sm, for: .scrollContent)
        .navigationTitle("Lists")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.settings.hiddenReminderListIDs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show All") {
                        Task { await viewModel.showAllReminderLists() }
                    }
                }
            }
        }
    }

    /// 색점 + 제목 + (표시 중이면) 체크마크. 행 전체가 44pt 터치 타깃.
    private func row(for list: ReminderList) -> some View {
        HStack(spacing: Spacing.smd) {
            Circle()
                // 리스트 색은 EventKit 데이터 표현이라 raw hex 허용(캘린더 색점과 동일 취급).
                .fill(list.colorHex.flatMap(Color.init(hex:)) ?? .secondary)
                .frame(width: Spacing.smd, height: Spacing.smd)
            Text(list.title)
                .foregroundStyle(.primary)
            Spacer()
            if !viewModel.settings.hiddenReminderListIDs.contains(list.id) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
    }
}
