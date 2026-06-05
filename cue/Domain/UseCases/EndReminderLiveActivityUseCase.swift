//
//  EndReminderLiveActivityUseCase.swift
//  cue / Domain
//

/// 미리알림 라이브 액티비티 즉시 종료. dismissalPolicy는 구현이 `.immediate` 적용.
struct EndReminderLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.endReminder()
    }
}
