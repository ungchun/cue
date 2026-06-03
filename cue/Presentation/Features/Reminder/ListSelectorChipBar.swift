//
//  ListSelectorChipBar.swift
//  cue / Presentation
//

import SwiftUI

/// 미리알림 화면 하단 칩 바. `tabViewBottomAccessory`에 부착되어 탭바와 함께
/// 스크롤 위치에 따라 분리(expanded)·통합(inline)된다.
///
/// 외곽 컨테이너는 system이 자동 제공한다 — 자체 `.glassEffect` 캡슐이나 외곽
/// padding을 두면 accessory의 system background와 **이중 캡슐**이 되어 좌우가
/// 좁아지고 안쪽 칩이 위로 치우친다. 그래서 여기는 ScrollView만 남기고
/// 외곽 장식은 모두 system에 맡긴다.
///
/// 칩 순서: 시스템 필터(오늘/예정/전체) → 세로 디바이더 → 사용자 리스트.
/// 선택된 칩만 안쪽 fill을 받고, 나머지는 텍스트만.
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
        }
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
