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

    // MARK: - Focus

    /// 집중 세션 라이브 액티비티 시작. 기존 Focus 인스턴스가 있으면 먼저 end.
    /// `phaseStartDate`·`phaseEndDate`는 widget timer interval의 안정적 양 끝 — 시스템 타이머가
    /// 그 사이를 매 프레임 자동 갱신한다.
    /// `colorHex`는 외곽 stroke·아이콘 등에 widget이 사용하는 세션 색. nil이면 widget이
    /// 시스템 accent로 폴백. 활동 시작 후 불변 → attributes에 저장.
    func startFocus(
        sessionID: UUID,
        sessionTitle: String,
        colorHex: String?,
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date
    ) async throws

    /// 집중 라이브 액티비티 상태 변경 — 일시정지/재개/스킵/페이즈 전환에서만.
    /// 매초 update 금지(시스템 타이머 위임). resume 시 `phaseStartDate`는 `now - elapsed`로
    /// 다시 잡아 interval 길이를 phaseDuration 그대로 유지한다.
    func updateFocus(
        phase: LiveFocusPhase,
        phaseStartDate: Date,
        phaseEndDate: Date,
        pauseTime: Date?
    ) async throws

    /// 집중 세션 종료. 완료 결과를 잠깐 보여주기 위해 dismiss를 60초 뒤로 미룬다.
    func endFocus() async

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

    /// 오늘·내일 일정 스냅샷을 라이브 액티비티로 게시.
    func startSchedule(
        today: [LiveEventItem],
        tomorrow: [LiveEventItem]
    ) async throws

    /// 일정 라이브 액티비티 즉시 종료.
    func endSchedule() async

    // MARK: - Sync

    /// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 재포착해 내부 핸들 복원.
    /// 호출 결과는 service 내부 상태에 반영되며, 외부에 노출은 별도 query API로 한다(추후).
    func sync() async
}
