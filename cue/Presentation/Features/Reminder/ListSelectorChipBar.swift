//
//  ListSelectorChipBar.swift
//  cue / Presentation
//

import SwiftUI

/// 미리알림 화면 하단 — 탭바 바로 위에 고정되는 칩 바.
///
/// 구조: **단일 외곽 Liquid Glass 캡슐** 안에 모든 칩이 묶인다. 칩 순서는
/// 시스템 필터 칩들(오늘/예정/전체) → 세로 디바이더 → 사용자 리스트 칩들.
/// 모든 칩은 같은 시각 형태이며, 외곽 캡슐 폭을 넘어가면 함께 가로 스크롤된다.
/// 선택된 칩만 안쪽 fill을 받고, 나머지는 텍스트만.
///
/// 외곽 캡슐은 `.glassEffect(.regular, in: .capsule)` — iOS 26 정식 API.
struct ListSelectorChipBar: View {
    let lists: [ReminderList]
    let selection: ReminderSelection?
    let onSelectList: (ReminderList) -> Void
    let onSelectFilter: (SystemFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // 시스템 필터 칩 — 오늘 / 예정 / 전체.
                ForEach(SystemFilter.allCases, id: \.self) { filter in
                    Button {
                        onSelectFilter(filter)
                    } label: {
                        chipLabel(filter.title, isSelected: selection == .systemFilter(filter))
                    }
                    .buttonStyle(.plain)
                }

                // 세로 디바이더 — 시스템 필터와 사용자 리스트 사이.
                Divider()
                    .frame(height: Spacing.md)
                    .padding(.horizontal, Spacing.xs)

                // 사용자 리스트 칩들.
                ForEach(lists) { list in
                    Button {
                        onSelectList(list)
                    } label: {
                        chipLabel(list.title, isSelected: selection == .list(list.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.xs)
        }
        // 단일 외곽 Liquid Glass 캡슐 — ScrollView 자체에 적용해
        // 안쪽 칩 묶음이 한 컨테이너 안에서 함께 스크롤된다.
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .padding(.bottom, Spacing.xs)
    }

    /// 칩 본체 — 선택은 안쪽 캡슐 fill + primary 텍스트, 미선택은 텍스트만(secondary).
    /// 안쪽 fill은 `.regularMaterial` — 외곽 glass 위에 stack되어 살짝 짙은 톤이 묻어난다.
    @ViewBuilder
    private func chipLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.callout)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background {
                if isSelected {
                    Capsule().fill(.regularMaterial)
                }
            }
            .contentShape(Capsule())
    }
}
