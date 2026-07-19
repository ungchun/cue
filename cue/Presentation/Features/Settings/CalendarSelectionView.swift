//
//  CalendarSelectionView.swift
//  cue / Presentation
//

import SwiftUI

/// 일정 탭에 표시할 캘린더를 고르는 전용 화면 — 설정 > 일정 > 캘린더에서 push된다.
/// 애플 캘린더 앱의 캘린더 표시/숨김과 같은 형태: 색점 + 이름 + 체크마크 목록.
/// 행을 탭하면 그 자리에서 표시/숨김이 토글되고 화면은 유지된다(뒤로가기로 닫힘) —
/// Menu가 매 토글마다 닫히던 문제를 없앤다.
struct CalendarSelectionView: View {
    let viewModel: SettingsViewModel

    var body: some View {
        List {
            ForEach(viewModel.eventCalendars) { calendar in
                Button {
                    let isVisible = !viewModel.settings.hiddenCalendarIDs.contains(calendar.id)
                    Task { await viewModel.setCalendarVisible(calendar.id, !isVisible) }
                } label: {
                    row(for: calendar)
                }
                .buttonStyle(.plain)
            }
        }
        // 기본 List 상단 인셋이 과해 비어 보인다 — SettingsView와 같은 방식으로 상단 여백 축소.
        .contentMargins(.top, Spacing.sm, for: .scrollContent)
        .navigationTitle("Calendars")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 일부라도 숨겨져 있을 때만 "모두 표시" 노출 — 20개 규모에서 한 번에 되돌리기.
            if !viewModel.settings.hiddenCalendarIDs.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Show All") {
                        Task { await viewModel.showAllCalendars() }
                    }
                }
            }
        }
    }

    /// 색점 + 제목 + (표시 중이면) 체크마크. 행 전체가 44pt 터치 타깃.
    private func row(for calendar: EventCalendar) -> some View {
        HStack(spacing: Spacing.smd) {
            Circle()
                // 캘린더 색은 EventKit 데이터 표현이라 raw hex 허용(미리알림 리스트 색점과 동일 취급).
                .fill(calendar.colorHex.flatMap(Color.init(hex:)) ?? .secondary)
                .frame(width: Spacing.smd, height: Spacing.smd)
            Text(calendar.title)
                .foregroundStyle(.primary)
            Spacer()
            if !viewModel.settings.hiddenCalendarIDs.contains(calendar.id) {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var viewModel = SettingsViewModel(dependencies: .preview)
    NavigationStack {
        CalendarSelectionView(viewModel: viewModel)
    }
    .task { await viewModel.onAppear() }
}
