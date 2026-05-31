//
//  FocusViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 집중 탭(idle 상태)의 ViewModel — 설정을 들고 있다가 사용자가 "시작"을 누르면 `session`을
/// 만들어 풀스크린 시트의 뷰모델로 노출한다. `session != nil`이 곧 시트 표시 신호.
///
/// 알림 권한 요청과 알림 스케줄러 주입을 이 레이어에서 일괄 처리해 화면 진입 시 한 번만
/// 권한 prompt가 뜨도록 한다(설정 시 무관, 시작 시 무관).
@MainActor
@Observable
final class FocusViewModel {
    /// 다음 세션에 쓸 설정. picker가 직접 바인딩한다.
    var settings: FocusSettings = .default
    /// 진행 중인 세션. nil이면 idle(설정 화면), 값이 있으면 풀스크린 시트를 띄운다.
    var session: FocusSessionViewModel?

    private let scheduler: any FocusNotificationScheduling

    init(dependencies: Dependencies) {
        self.scheduler = dependencies.focusNotifications
    }

    /// 화면이 처음 나타날 때 한 번 호출 — 알림 권한 prompt를 미리 띄워 시작 시 끊김을 막는다.
    func onAppear() async {
        await scheduler.requestAuthorization()
    }

    /// 현재 `settings`로 새 세션을 만든다. 이미 세션이 떠 있으면 무시.
    func start() {
        guard session == nil else { return }
        session = FocusSessionViewModel(settings: settings, scheduler: scheduler)
    }

    /// 진행 중인 세션을 중단·정리한다. 시트의 종료 버튼·강제 dismiss에서 호출.
    func stopSession() {
        session?.abort()
        session = nil
    }
}
