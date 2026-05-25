//
//  ListSelectorChipBar.swift
//  cue / Presentation
//

import SwiftUI

/// 미리알림 화면 하단 — 탭바 바로 위에 고정되는 칩 바.
///
/// 구조: **단일 외곽 Liquid Glass 캡슐** 안에 모든 칩이 묶인다. 칩 순서는
/// 시스템 필터 칩들(`오늘` / `예정` / `전체`, UI만) → 세로 디바이더 →
/// 사용자 리스트 칩들. 모든 칩은 같은 시각 형태이며, 외곽 캡슐 폭을 넘어가면
/// 함께 가로 스크롤된다. 선택된 리스트 칩만 안쪽 fill을 받고, 나머지는 텍스트만.
///
/// 외곽 캡슐은 `.glassEffect(.regular, in: .capsule)` — iOS 26 정식 API.
struct ListSelectorChipBar: View {
    /// 시스템 필터 칩 라벨들 — 다음 사이클에서 실제 selection state와 묶인다.
    /// 지금은 자리만 잡고 모두 비선택.
    private let systemFilters = ["오늘", "예정", "전체"]

    let lists: [ReminderList]
    let selectedListID: String?
    let onSelect: (ReminderList) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // 시스템 필터 칩들 — UI만, 탭 동작은 다음 사이클.
                ForEach(systemFilters, id: \.self) { filter in
                    Button {
                        // 다음 사이클에서 — 필터 selection state 연결.
                    } label: {
                        chipLabel(filter, isSelected: false)
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
                        onSelect(list)
                    } label: {
                        chipLabel(list.title, isSelected: list.id == selectedListID)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xs)
        }
        // 단일 외곽 Liquid Glass 캡슐 — ScrollView 자체에 적용해
        // 안쪽 칩 묶음이 한 컨테이너 안에서 함께 스크롤된다.
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.sm)
    }

    /// 칩 본체 — 선택은 안쪽 캡슐 fill + primary 텍스트, 미선택은 텍스트만(secondary).
    /// 안쪽 fill은 `.regularMaterial` — 외곽 glass 위에 stack되어 살짝 짙은 톤이 묻어난다.
    /// vertical padding은 `Spacing.md`로 칩 높이를 확보한다.
    @ViewBuilder
    private func chipLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(AppFont.bodySmall)
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.md)
            .background {
                if isSelected {
                    Capsule().fill(.regularMaterial)
                }
            }
            .contentShape(Capsule())
    }
}
