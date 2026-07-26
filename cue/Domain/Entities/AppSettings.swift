//
//  AppSettings.swift
//  cue / Domain
//

import Foundation

/// 앱 화면 밝기 테마. 시스템 설정을 따르거나(.system) 라이트·다크로 고정.
enum AppColorScheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

/// 메모 텍스트 크기 — 입력 화면과 라이브 액티비티 카드에 공통 적용. 기본은 현재 동작인 `.large`.
enum MemoTextSize: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large
}

/// 앱 전역 설정. 단일 인스턴스로 UserDefaults에 JSON 저장된다(스코프 없음 —
/// 섹션·리스트별로 나뉘는 `ReminderSortSettings`와 달리 앱에 하나뿐).
///
/// 필드는 기능이 추가될 때마다 늘어난다. 그래서 `init(from:)`을 직접 구현해
/// **저장 당시 없던 새 필드를 기본값으로 채운다**(전방 호환) — 설정 하나를 더해도
/// 기존 사용자의 저장본이 통째로 버려지지 않게 하기 위함.
struct AppSettings: Codable, Equatable, Sendable {
    /// 앱 전체 밝기 테마.
    var colorScheme: AppColorScheme
    /// 앱을 켤 때 처음 보여줄 탭의 식별자(`AppTab.rawValue`). 기본은 할일.
    /// Domain은 `AppTab`(Presentation·SwiftUI)을 모르므로 문자열로만 보관한다.
    var startTabID: String
    /// 집중 단계 종료 시 실제 알림 소리를 낼지. `false`면 무음(현재 기본 동작).
    var focusEndSound: Bool
    /// 메모 텍스트 크기. 기본 `.large`(현재 largeTitle 동작 유지).
    var memoTextSize: MemoTextSize
    /// 메모 잠금화면 LA에 월간 캘린더를 함께 표시할지. `false`면 메모만(현재 기본 동작).
    var memoShowsCalendar: Bool
    /// 일정 잠금화면 LA에 월간 캘린더를 함께 표시할지. `false`면 일정만(현재 기본 동작).
    var scheduleShowsCalendar: Bool
    /// 할일 라이브 액티비티에 월간 캘린더를 함께 표시할지 — 일정 캘린더와 동일 동작(Premium).
    var reminderShowsCalendar: Bool
    /// 라이브 액티비티 항상 표시(마스터). `false`면 현재처럼 수동 토글로만 게시.
    var liveAlwaysOn: Bool
    /// 항상 표시 대상 — 메모/할일/일정. 마스터 on일 때만 의미. 기본 셋 다 on.
    var liveAlwaysOnMemo: Bool
    var liveAlwaysOnReminder: Bool
    var liveAlwaysOnSchedule: Bool
    /// 항상 표시 할일 LA의 범위 — "today"/"scheduled"/"all" 또는 사용자 리스트 id.
    /// Domain은 Presentation의 필터 타입을 모르므로 문자열로 보관(startTabID 전례). 기본 전체.
    var liveAlwaysOnReminderScopeID: String
    /// 할일 탭에 진입했을 때 처음 보여줄 범위 — "today"/"scheduled"/"all" 또는 사용자 리스트 id.
    /// 인코딩은 `liveAlwaysOnReminderScopeID`와 동일하나, 이쪽은 LA가 아니라 **화면 진입 시
    /// 초기 선택**을 정한다("Off" 없음 — 항상 무언가는 보여야 하므로). 기본 전체.
    var tasksDefaultScopeID: String
    /// 일정 탭에서 **숨길** 캘린더의 식별자 집합. 비어 있으면 전부 표시(기본). 숨김을 저장하므로
    /// 새로 생긴 캘린더는 자동으로 표시된다(애플 캘린더와 동일 동작). `EventCalendar.id` 값.
    var hiddenCalendarIDs: Set<String>
    /// 할일 탭에서 **숨길** 미리알림 리스트의 식별자 집합. 비어 있으면 전부 표시(기본).
    /// 캘린더 숨김과 동일 동작 — 숨긴 리스트의 할일은 오늘·예정·전체 어디서도 안 보이고,
    /// 목록 칩에서도 빠진다. 오늘/예정/전체 시스템 필터는 항상 유지. `ReminderList.id` 값.
    var hiddenReminderListIDs: Set<String>
    /// 첫 실행 온보딩을 끝(완료 또는 스킵)까지 봤는지. `false`면 앱 시작 시 온보딩 표시.
    var hasCompletedOnboarding: Bool
    /// 온보딩을 **표시한 적** 있는지 — 도중(첫 큐 게시가 메모를 저장한 뒤) 앱이 종료돼도
    /// 다음 실행에서 기존 설치 흔적으로 오판해 조용히 완주 처리하지 않고 이어서 보여준다.
    var hasStartedOnboarding: Bool

    // MARK: 강등으로 접어둔 프리미엄 설정 — 재구독 확인 시 자동 복구 후 비운다.
    // 강등 정리가 파괴적이면(기록 없이 끄기만) 오판·재구독 사용자가 수동으로 다시 켜야 한다.
    // 인라인 기본값 — memberwise init에 기본 인자로 붙어 기존 생성 호출부가 그대로 컴파일된다.

    /// 강등 정리가 끈 항상 표시 — 원래 켜져 있었음의 기록.
    var demotedLiveAlwaysOn: Bool = false
    /// 강등 정리가 끈 캘린더 함께 보기(메모/일정/할일) — 원래 켜져 있었음의 기록.
    var demotedMemoShowsCalendar: Bool = false
    var demotedScheduleShowsCalendar: Bool = false
    var demotedReminderShowsCalendar: Bool = false
    /// 강등 정리가 되돌린 메모 LA 커스텀 색 — 원래 값의 기록. nil이면 기록 없음.
    var demotedMemoColorHex: String?
    var demotedMemoTextColorHex: String?

    static let `default` = AppSettings(
        colorScheme: .system,
        startTabID: "memo",
        focusEndSound: false,
        memoTextSize: .medium,
        memoShowsCalendar: false,
        scheduleShowsCalendar: false,
        reminderShowsCalendar: false,
        liveAlwaysOn: false,
        liveAlwaysOnMemo: true,
        liveAlwaysOnReminder: true,
        liveAlwaysOnSchedule: true,
        liveAlwaysOnReminderScopeID: "all",
        tasksDefaultScopeID: "all",
        hiddenCalendarIDs: [],
        hiddenReminderListIDs: [],
        hasCompletedOnboarding: false,
        hasStartedOnboarding: false
    )
}

extension AppSettings {
    /// 전방 호환 디코딩 — 저장 당시 없던 키는 `.default`의 값으로 채운다.
    /// (필드를 추가해도 옛 JSON이 디코딩 실패로 통째로 날아가지 않도록.)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        colorScheme = try container.decodeIfPresent(AppColorScheme.self, forKey: .colorScheme)
            ?? fallback.colorScheme
        startTabID = try container.decodeIfPresent(String.self, forKey: .startTabID)
            ?? fallback.startTabID
        focusEndSound = try container.decodeIfPresent(Bool.self, forKey: .focusEndSound)
            ?? fallback.focusEndSound
        memoTextSize = try container.decodeIfPresent(MemoTextSize.self, forKey: .memoTextSize)
            ?? fallback.memoTextSize
        memoShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .memoShowsCalendar)
            ?? fallback.memoShowsCalendar
        scheduleShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .scheduleShowsCalendar)
            ?? fallback.scheduleShowsCalendar
        reminderShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .reminderShowsCalendar)
            ?? fallback.reminderShowsCalendar
        liveAlwaysOn = try container.decodeIfPresent(Bool.self, forKey: .liveAlwaysOn)
            ?? fallback.liveAlwaysOn
        liveAlwaysOnMemo = try container.decodeIfPresent(Bool.self, forKey: .liveAlwaysOnMemo)
            ?? fallback.liveAlwaysOnMemo
        liveAlwaysOnReminder = try container.decodeIfPresent(Bool.self, forKey: .liveAlwaysOnReminder)
            ?? fallback.liveAlwaysOnReminder
        liveAlwaysOnSchedule = try container.decodeIfPresent(Bool.self, forKey: .liveAlwaysOnSchedule)
            ?? fallback.liveAlwaysOnSchedule
        liveAlwaysOnReminderScopeID = try container.decodeIfPresent(String.self, forKey: .liveAlwaysOnReminderScopeID)
            ?? fallback.liveAlwaysOnReminderScopeID
        tasksDefaultScopeID = try container.decodeIfPresent(String.self, forKey: .tasksDefaultScopeID)
            ?? fallback.tasksDefaultScopeID
        hiddenCalendarIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenCalendarIDs)
            ?? fallback.hiddenCalendarIDs
        hiddenReminderListIDs = try container.decodeIfPresent(Set<String>.self, forKey: .hiddenReminderListIDs)
            ?? fallback.hiddenReminderListIDs
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
            ?? fallback.hasCompletedOnboarding
        hasStartedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasStartedOnboarding)
            ?? fallback.hasStartedOnboarding
        demotedLiveAlwaysOn = try container.decodeIfPresent(Bool.self, forKey: .demotedLiveAlwaysOn)
            ?? fallback.demotedLiveAlwaysOn
        demotedMemoShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .demotedMemoShowsCalendar)
            ?? fallback.demotedMemoShowsCalendar
        demotedScheduleShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .demotedScheduleShowsCalendar)
            ?? fallback.demotedScheduleShowsCalendar
        demotedReminderShowsCalendar = try container.decodeIfPresent(Bool.self, forKey: .demotedReminderShowsCalendar)
            ?? fallback.demotedReminderShowsCalendar
        demotedMemoColorHex = try container.decodeIfPresent(String.self, forKey: .demotedMemoColorHex)
        demotedMemoTextColorHex = try container.decodeIfPresent(String.self, forKey: .demotedMemoTextColorHex)
    }
}
