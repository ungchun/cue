//
//  ScheduleView.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 일정 탭 화면 — "타임라인" 헤더 + 우상단 신규 이벤트 + 버튼.
///
/// 시간순 이벤트 리스트는 후속 사이클에서. 현재는 권한·신규 입력만 다룬다.
/// 신규 입력은 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가 처리한다.
///
/// `eventStore`는 화면 진입 시 한 번 만들어 warm-up하고 `EventEditSheet`에 그대로
/// 주입한다 — 시트 안에서 새 store를 만들면 캘린더 목록·기본 캘린더 조회가 시트 표시
/// 시점에 처음 일어나 데이터가 한 박자 늦게 채워지고 시스템 로그가 무더기로 찍힌다.
struct ScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel
    /// 신규 이벤트 시트와 공유하는 EKEventStore. `@State`로 view 생애 동안 유지한다.
    @State private var eventStore = EKEventStore()

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
            .task {
                await viewModel.onAppear()
                warmUpEventStore()
            }
            .sheet(isPresented: $viewModel.showingNewEvent) {
                EventEditSheet(eventStore: eventStore, onCompletion: {
                    viewModel.dismissNewEvent()
                })
            }
    }

    /// 권한이 허용된 직후 `eventStore`의 캘린더 목록·기본 캘린더 캐시를 미리 채워둔다.
    /// 첫 호출은 EventKit이 시스템 캘린더 DB·플러그인·persona 서비스에 접근하는 비용이
    /// 있어 시트 표시 시점으로 미루면 데이터 지연·시스템 로그가 사용자에게 노출된다.
    /// 화면 진입 직후 한 번 끌어두면 그 비용이 사전 분산된다.
    private func warmUpEventStore() {
        guard viewModel.access == .granted else { return }
        _ = eventStore.calendars(for: .event)
        _ = eventStore.defaultCalendarForNewEvents
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
