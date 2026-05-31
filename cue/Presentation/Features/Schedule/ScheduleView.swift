//
//  ScheduleView.swift
//  cue / Presentation
//

import SwiftUI

/// 일정 탭 화면 — "타임라인" 헤더 + 우상단 신규 이벤트 + 버튼.
///
/// 시간순 이벤트 리스트는 후속 사이클에서. 현재는 권한·신규 입력만 다룬다.
/// 신규 입력은 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가 처리한다.
struct ScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel

    var body: some View {
        content
            .navigationTitle("타임라인")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.presentNewEvent()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("새 일정")
                }
            }
            .task { await viewModel.onAppear() }
            .sheet(isPresented: $viewModel.showingNewEvent) {
                EventEditSheet(onCompletion: {
                    viewModel.dismissNewEvent()
                })
            }
    }

    /// 본문 — 권한 상태에 따라 안내, 권한이 있으면 빈 타임라인 placeholder.
    /// 이벤트 리스트는 다음 사이클에서.
    @ViewBuilder
    private var content: some View {
        switch viewModel.access {
        case .notDetermined, .denied:
            ContentUnavailableView(
                "캘린더 접근이 필요해요",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("설정 → cue 에서 캘린더 권한을 켜 주세요.")
            )
        case .granted:
            ContentUnavailableView(
                "일정이 비어있어요",
                systemImage: "calendar",
                description: Text("우측 상단 +로 새 일정을 추가하세요.")
            )
        }
    }
}

#Preview {
    NavigationStack {
        ScheduleView(viewModel: ScheduleViewModel(dependencies: .preview))
    }
}
