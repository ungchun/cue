//
//  SyncLiveActivitiesUseCase.swift
//  cue / Domain
//

/// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 service가 재포착하게 한다.
/// 사용자가 앱을 강제 종료한 동안에도 시스템이 Activity를 보존하므로, 복귀 시 동기화로
/// service 내부 핸들을 복원해 "이미 떠 있는" 상태를 ViewModel이 알 수 있게 한다.
/// `cueApp.task` 안에서 한 번 await.
struct SyncLiveActivitiesUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.sync()
    }
}
