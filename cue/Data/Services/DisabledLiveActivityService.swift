//
//  DisabledLiveActivityService.swift
//  cue / Data
//

import Foundation

/// 라이브 액티비티가 비활성/미지원 환경(Preview·Test·시뮬레이터 일부)용 no-op 구현.
///
/// "아무 일도 안 함"이 목적 — 시스템 설정에서 OFF인 사용자 경로의 stub은
/// `ActivityKitLiveActivityService`가 `isEnabled = false`로 자체 분기해 처리한다.
/// 여기는 의존성 만족용 fallback. `isEnabled = false`를 반환해 use case가 호출을
/// 시도하지 않도록 한다.
struct DisabledLiveActivityService: LiveActivityService {
    var isEnabled: Bool {
        get async { false }
    }

    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int,
        todayCount: Int
    ) async throws {}

    func endReminder() async {}

    func startSchedule(days: [LiveScheduleDay], todayCount: Int) async throws {}

    func endSchedule() async {}

    func sync() async {}
}
