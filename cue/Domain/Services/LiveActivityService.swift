//
//  LiveActivityService.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티 라이프사이클 추상화 — Domain 계층은 `ActivityKit`을 모른다.
/// 구체 구현(`ActivityKitLiveActivityService`)이 Data 계층에서 `Activity<…>`를 다룬다.
///
/// 한 kind당 동시 **최대 1개**. 같은 kind로 `start`를 다시 호출하면 구현이 기존 인스턴스를
/// 먼저 `end(.immediate)` 처리하고 새로 시작한다 — 호출처(ViewModel)는 토글성 트리거
/// 작성 시 그 단순화를 가정해도 된다.
///
/// `sync()`는 앱 시작 시 시스템에 살아있는 Activity들을 재포착하기 위한 hook.
/// 사용자가 앱을 강제 종료한 동안에도 시스템은 Activity를 보존하므로, 복귀 시 동기화로
/// "Live Activity가 이미 떠 있다"는 사실을 ViewModel이 알 수 있게 한다.
protocol LiveActivityService: Sendable {
    /// 시스템 설정 + OS budget상 라이브 액티비티가 활성화돼 있는지.
    /// `request` 호출 직전마다 확인 — false면 use case가 `request` 호출 자체를 막고
    /// "설정 열기" UX로 분기한다.
    var isEnabled: Bool { get async }

    // 집중(Focus) LA는 AlarmKit으로 이관됨 — 이 서비스는 Reminder/Schedule LA만 담당한다.

    // MARK: - Reminder

    /// 미리알림 리스트 스냅샷을 라이브 액티비티로 게시.
    /// `items`가 시스템에 표시 가능한 한도(6)를 넘으면 구현이 잘라 사용하고 나머지 개수는
    /// `remaining`에 들어간 그대로 표시한다 — 잘라내기 결정은 호출처에서.
    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int
    ) async throws

    /// 미리알림 라이브 액티비티 즉시 종료.
    func endReminder() async

    // MARK: - Schedule

    /// 일정 스냅샷(날짜별 묶음, 오늘부터)을 라이브 액티비티로 게시.
    func startSchedule(days: [LiveScheduleDay]) async throws

    /// 일정 라이브 액티비티 즉시 종료.
    func endSchedule() async

    // MARK: - Sync

    /// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 재포착해 내부 핸들 복원.
    /// 호출 결과는 service 내부 상태에 반영되며, 외부에 노출은 별도 query API로 한다(추후).
    func sync() async
}
