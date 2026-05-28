//
//  ScheduleViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭의 상태 + 동작. 현재는 권한과 신규 이벤트 시트 표시 여부만 다룬다.
///
/// 신규 이벤트 입력은 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가 처리하므로
/// ViewModel은 시트 표시/닫힘 상태만 관리한다. 이벤트 fetch·표시 로직은 후속 사이클에서.
@MainActor
@Observable
final class ScheduleViewModel {
    private let requestAccessUseCase: RequestEventsAccessUseCase

    private(set) var access: EventsAccess = .notDetermined
    /// 우상단 + 버튼이 띄우는 "신규 이벤트" 시트 표시 여부.
    var showingNewEvent = false

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestEventsAccess
    }

    /// 화면이 나타날 때 한 번 호출. 권한 요청을 수행하고 상태를 반영한다.
    func onAppear() async {
        access = await requestAccessUseCase()
    }

    /// + 버튼 액션 — 신규 이벤트 시트를 연다.
    func presentNewEvent() {
        showingNewEvent = true
    }

    /// 시트의 저장·취소 콜백에서 호출 — 시트를 닫는다.
    func dismissNewEvent() {
        showingNewEvent = false
    }
}
