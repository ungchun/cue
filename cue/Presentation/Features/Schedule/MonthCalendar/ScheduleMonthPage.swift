//
//  ScheduleMonthPage.swift
//  cue / Presentation
//

import SwiftUI

/// 월 페이저의 한 페이지 — 그 달의 주 행들을 세로로 쌓는다.
///
/// 항목 수 제한이 없어 한 달이 화면보다 길어질 수 있으므로 페이지마다 세로 스크롤을 둔다.
struct ScheduleMonthPage: View {
    let viewModel: ScheduleMonthViewModel
    let offset: Int

    @Environment(\.displayScale) private var displayScale
    /// 스크롤뷰의 보이는 높이(인셋 제외).
    @State private var viewportHeight: CGFloat = 0

    var body: some View {
        // 페이지 모델은 이 body 안에서만 꺼낸다 — 페이저가 241개 페이지를 만들 때 미리 평가하지 않고,
        // 실제로 그려지는 페이지만 VM 캐시에 올라가게.
        let page = viewModel.page(for: offset)
        let grid = page.grid
        let rowFillHeight = fillHeight(weekCount: grid.weeks.count)
        ScrollView(.vertical) {
            VStack(spacing: Spacing.zero) {
                ForEach(grid.weeks.indices, id: \.self) { index in
                    ScheduleMonthWeekRow(
                        page: page,
                        week: grid.weeks[index],
                        fillHeight: rowFillHeight
                    )
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 1 / displayScale)
                }
            }
            .background(ScrollBounceDisabler())
        }
        .scrollIndicators(.hidden)
        // 내용이 화면에 다 들어가면 스크롤 자체를 막는다.
        .scrollBounceBehavior(.basedOnSize)
        // 탭바·상단 인셋을 뺀 실제 보이는 높이 — 행들이 이 높이를 나눠 격자가 화면을 꽉 채운다.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom
        } action: { _, newValue in
            viewportHeight = newValue
        }
        // 첫 적재 동안 빈 격자만 보이지 않게 — 앱 다른 화면(할일 탭 등)과 같은 기본 인디케이터.
        .overlay {
            if !page.isLoaded {
                ProgressView()
            }
        }
    }

    /// 주 하나가 가져갈 높이 = (보이는 높이 − 주 구분선) ÷ 주 수. 픽셀 단위로 내림 —
    /// 반올림 오차로 내용이 보이는 높이를 한 점이라도 넘으면 빈 달인데도 스크롤이 생긴다.
    private func fillHeight(weekCount: Int) -> CGFloat {
        guard weekCount > 0, viewportHeight > 0 else { return 0 }
        let hairlines = CGFloat(weekCount) / displayScale
        let perRow = (viewportHeight - hairlines) / CGFloat(weekCount)
        return max(0, (perRow * displayScale).rounded(.down) / displayScale)
    }
}
