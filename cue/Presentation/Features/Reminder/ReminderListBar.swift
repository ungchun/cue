//
//  ReminderListBar.swift
//  cue / Presentation
//

import SwiftUI

/// 탭바 위에 떠 있는 액세서리 — 미리 알림 리스트를 가로 칩으로 보여주고,
/// ☰ 메뉴로 전체 리스트(미완료 개수 포함)를 펼친다.
///
/// `TabView`의 `tabViewBottomAccessory`에 부착된다 — 떠 있는 캡슐 모양은 시스템이 그린다.
struct ReminderListBar: View {
    let viewModel: ReminderViewModel

    var body: some View {
        HStack(spacing: Spacing.sm) {
            ScrollView(.horizontal) {
                HStack(spacing: Spacing.xs) {
                    ForEach(viewModel.lists) { list in
                        chip(for: list)
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }
            .scrollIndicators(.hidden)

            listMenu
                .padding(.trailing, Spacing.sm)
        }
    }

    /// 리스트 칩 하나 — 선택된 칩은 캡슐로 채워진다.
    private func chip(for list: ReminderList) -> some View {
        let isSelected = viewModel.selectedListID == list.id
        return Button {
            viewModel.select(list)
        } label: {
            Text(list.title)
                .font(AppFont.bodyLarge)
                .foregroundStyle(isSelected ? AppColor.textPrimary : AppColor.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background {
                    if isSelected {
                        Capsule().fill(AppColor.surfaceSecondary)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// ☰ 메뉴 — 전체 리스트 + 미완료 개수, 선택 항목에 체크마크.
    private var listMenu: some View {
        Menu {
            ForEach(viewModel.lists) { list in
                Button {
                    viewModel.select(list)
                } label: {
                    let count = viewModel.incompleteCount(in: list)
                    if viewModel.selectedListID == list.id {
                        Label("\(list.title) (\(count))", systemImage: "checkmark")
                    } else {
                        Text("\(list.title) (\(count))")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal")
        }
    }
}
