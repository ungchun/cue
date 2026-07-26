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
    /// `showsCalendarOverride` — 잠금화면 월간 캘린더 표시 강제. nil이면 설정 미러를 따른다.
    func startReminder(
        listTitle: String,
        items: [LiveReminderItem],
        remaining: Int,
        todayCount: Int,
        weekEventDots: [LiveDayEventDots],
        showsCalendarOverride: Bool?
    ) async throws

    /// 미리알림 라이브 액티비티 즉시 종료.
    func endReminder() async

    // MARK: - Schedule

    /// 일정 스냅샷(날짜별 묶음, 오늘부터)을 라이브 액티비티로 게시.
    /// `showsCalendarOverride` — 잠금화면 월간 캘린더 표시 강제. nil이면 설정 미러(App Group)를
    /// 따른다(기존 동작). 온보딩 목업 게시가 설정을 건드리지 않고 캘린더를 보여줄 때 true.
    func startSchedule(
        days: [LiveScheduleDay],
        todayCount: Int,
        weekEventDots: [LiveDayEventDots],
        showsCalendarOverride: Bool?
    ) async throws

    /// 일정 라이브 액티비티 즉시 종료.
    func endSchedule() async

    // MARK: - 온보딩 예시 정리

    /// 온보딩 예시 일정·할일 LA만 골라 종료 — `showsCalendarOverride`가 박힌 활동이 예시다
    /// (실사용 게시는 항상 nil). 앱 재시작으로 핸들이 유실돼도 시스템 컬렉션에서 식별해
    /// 정리할 수 있고, 실사용 LA를 건드릴 위험이 구조적으로 없다.
    func endSamples() async

    // MARK: - Memo

    /// 단일 메모를 큰 텍스트 카드로 라이브 액티비티에 게시. `text`는 use case가 빈 값 검증·
    /// 길이 제한을 마친 값, `colorHex`는 카드 배경색, `textColorHex`는 글자색.
    /// 이미 떠 있으면 구현이 부드럽게 update한다.
    func startMemo(text: String, colorHex: String, textColorHex: String) async throws

    /// 메모 라이브 액티비티 즉시 종료.
    func endMemo() async

    // MARK: - Sync

    /// 앱 시작 시 호출 — 시스템에 살아있는 Activity 인스턴스를 재포착해 내부 핸들 복원.
    /// 호출 결과는 service 내부 상태에 반영되며, 외부에 노출은 별도 query API로 한다(추후).
    func sync() async

    /// 켜져 있는 LA를 현재 상태 그대로 다시 게시(update) — 위젯이 렌더 시점에 읽는
    /// 설정(App Group 미러, 예: 캘린더 함께 표시)이 바뀐 직후 즉시 반영되게 한다.
    /// 위젯은 App Group 변경을 스스로 감지하지 못하므로 재게시로 재렌더를 유도해야 한다.
    func refreshLayout() async
}
