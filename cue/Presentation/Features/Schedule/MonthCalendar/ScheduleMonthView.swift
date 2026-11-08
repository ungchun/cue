//
//  ScheduleMonthView.swift
//  cue / Presentation
//

import SwiftUI

/// 일정 탭 월 모드 본문 — 큰 제목(보이는 달) + 라이브 버튼, 요일 헤더, 한 달씩 넘기는 가로 페이저.
/// 제목을 누르면 연·월 휠 팝오버로 먼 달에 바로 간다.
///
/// 제목 행·요일 헤더는 페이저 밖에 고정한다 — 달을 넘겨도 제자리에 있어야 "지금 몇 월인지"가
/// 흔들리지 않는다. 그래서 타임라인처럼 스크롤로 큰 제목이 가려지는 일이 없다.
struct ScheduleMonthView: View {
    let viewModel: ScheduleMonthViewModel
    /// 라이브 버튼 비활성 여부 — 타임라인과 같은 조건이어야 해서 호출처가 계산해 넘긴다.
    let isLiveDisabled: Bool
    /// 라이브 버튼 동작 — 타임라인과 같은 토글·토스트·리뷰 흐름을 호출처와 공유한다.
    let onLive: () async -> Void
    /// 칩 탭 — 일정은 이벤트 시트, 할일은 할일 시트. 시트는 탭 화면(`ScheduleView`)이 띄운다.
    let onSelectItem: (WidgetCalendarItem) -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMonthPicker = false

    var body: some View {
        VStack(spacing: Spacing.zero) {
            titleRow
            weekdayHeader
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1 / displayScale)
            pager
        }
        .task { await viewModel.onAppear() }
        // 앱 밖에서 권한을 켜고 돌아오거나 날이 바뀐 채 돌아오면 다시 읽는다. 첫 진입과 겹쳐도 VM이 병합한다.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await viewModel.sceneDidBecomeActive() }
        }
    }

    /// 타임라인 `timelineTitleRow`와 같은 폰트·인셋 — 모드를 바꿔도 제목·버튼 자리가 그대로다.
    private var titleRow: some View {
        HStack(alignment: .center) {
            monthTitleButton
            Spacer()
            FloatingMessageButton(action: onLive)
                .disabled(isLiveDisabled)
        }
        .padding(.init(
            top: Spacing.sm + Spacing.xxs, leading: Spacing.lg,
            bottom: Spacing.sm + Spacing.xxs, trailing: Spacing.md
        ))
    }

    /// 보이는 달 제목 + chevron — 누르면 연·월 피커. 꺾쇠로 "눌러서 고를 수 있음"을 알린다.
    private var monthTitleButton: some View {
        Button {
            showingMonthPicker = true
        } label: {
            // 월이 주인공, 연도는 같은 줄에 작고 가늘고 연하게 — 제목 높이를 그대로 두면서
            // "2026년 11월" 통째 굵은 한 줄의 답답함을 덜어낸다. 기준선을 맞춰 한 덩어리로 읽힌다.
            // Text `+`는 iOS 26에서 폐기, 보간은 새 카탈로그 키("%@ %@")를 만들어 두 Text를 나란히 둔다.
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(viewModel.visibleMonthName)
                    .font(.largeTitle.bold())
                    .lineLimit(1)
                    // 긴 월 이름("September")이 라이브 버튼에 밀려 잘리지 않게.
                    .minimumScaleFactor(0.7)
                Text(viewModel.visibleYear)
                    .font(.title2.weight(.regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    // 굵은 월 바로 옆에 붙으면 한 덩어리로 뭉쳐 보여서, 월과의 사이만 조금 더 띄운다.
                    .padding(.leading, Spacing.xs)
                // 제목보다 작게 해 제목이 주인공으로 남고, 굵게 해 작아도 또렷하게.
                Image(systemName: "chevron.down")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)
            }
        }
        // 기본 버튼 스타일은 제목을 tint로 칠한다 — 타임라인 제목과 같은 primary를 유지.
        .buttonStyle(.plain)
        // VoiceOver는 chevron 이름 없이 제목만 읽는다(새 문자열을 만들지 않으려 힌트도 두지 않음).
        .accessibilityLabel(viewModel.visibleMonthTitle)
        // 제목에 붙여 화살표가 제목을 가리키게 — 무엇을 고르는 카드인지 바로 읽힌다.
        .popover(isPresented: $showingMonthPicker, arrowEdge: .top) {
            ScheduleMonthPickerSheet(viewModel: viewModel)
        }
    }

    /// 요일 헤더 — 주 시작 요일은 격자가 정한다. 칸 사이에 주 행과 같은 폭의 투명 선을 둬
    /// 열 경계가 아래 격자와 정확히 맞는다.
    private var weekdayHeader: some View {
        let grid = viewModel.page(for: viewModel.visibleOffset).grid
        return HStack(spacing: Spacing.zero) {
            ForEach(0..<7, id: \.self) { column in
                if column > 0 {
                    // 높이 0 고정 — Color는 세로로 무한히 늘어나 헤더가 페이저와 높이를 나눠 갖는다.
                    Color.clear.frame(width: 1 / displayScale, height: Spacing.zero)
                }
                Text(grid.weekdaySymbols.indices.contains(column) ? grid.weekdaySymbols[column] : "")
                    .font(.caption2)
                    // 날짜 숫자보다 한참 작게 — caption2가 가장 작은 텍스트 스타일이라 시스템 보조 글자 배율로 한 단 더 줄인다.
                    .textScale(.secondary)
                    .foregroundStyle(Self.weekdayColor(grid.weekdayIndex(column: column)))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityHidden(true)
    }

    /// 한 달 = 한 페이지. 선택을 VM의 `visibleOffset`에 묶어 제목이 따라 바뀐다.
    /// 페이지 TabView를 쓰는 이유 — LazyHStack 페이징은 첫 위치가 `scrollPosition` 초기값을
    /// 확실히 따르지 않아 엉뚱한 달에서 시작할 수 있다. TabView는 선택한 페이지에서 시작한다.
    private var pager: some View {
        TabView(selection: Bindable(viewModel).visibleOffset) {
            ForEach(viewModel.monthOffsets, id: \.self) { offset in
                ScheduleMonthPage(viewModel: viewModel, offset: offset, onSelect: onSelectItem)
                    .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    /// 요일 헤더 색 — 일요일 빨강, 토요일 파랑, 평일은 날짜 숫자보다 한 단계 물러난 secondary.
    private static func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: return .red
        case 7: return .blue
        default: return .secondary
        }
    }
}
