//
//  SettingsViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 설정 탭의 상태 + 동작.
///
/// 앱 전역 설정(`AppSettings`)의 단일 소유자다 — 진입 시 불러오고, 항목을 바꾸면
/// 즉시 메모리에 반영한 뒤 영속 저장한다. `colorScheme`처럼 앱 전체에 즉시 반영돼야 하는
/// 값은 `RootView`가 이 ViewModel을 관찰해 적용한다.
/// (각 기능 ViewModel은 자기 화면 진입 시 `FetchAppSettingsUseCase`로 따로 읽는다.)
@MainActor
@Observable
final class SettingsViewModel {
    private let fetchAppSettings: FetchAppSettingsUseCase
    private let saveAppSettings: SaveAppSettingsUseCase
    private let fetchMemoUseCase: FetchMemoUseCase
    private let saveMemoUseCase: SaveMemoUseCase
    private let refreshLiveActivityLayout: RefreshLiveActivityLayoutUseCase
    private let fetchReminderLists: FetchReminderListsUseCase
    private let fetchCalendars: FetchCalendarsUseCase
    private let analytics: any AnalyticsService

    /// 현재 설정. View는 읽기만 하고, 변경은 아래 `set...` 메서드로.
    private(set) var settings: AppSettings = .default
    /// 메모 라이브 액티비티 카드 배경 색(hex). 설정의 일부가 아니라 단일 `Memo`의 속성을
    /// 여기서 편집한다 — 메모 화면의 색 선택 UI가 제거되어 설정 탭이 유일한 색 편집면이다.
    /// 출처는 `Memo.colorHex`(LA ContentState로 위젯에 그대로 실린다).
    private(set) var memoColorHex: String = Memo.default.colorHex
    /// 메모 라이브 액티비티 카드 글자(폰트) 색(hex). 출처는 `Memo.textColorHex`.
    private(set) var memoTextColorHex: String = Memo.default.textColorHex
    /// 메모 라이브 액티비티 미리보기에 실을 현재 메모 본문. 출처는 `Memo.text`.
    /// 비어 있으면 미리보기 뷰가 샘플 문구로 대체한다(설정 화면은 편집면이 아니라 표시용).
    private(set) var memoText: String = Memo.default.text
    /// 항상 표시 할일 범위 선택지용 사용자 리스트 — 권한 없으면 빈 배열(시스템 필터만 노출).
    private(set) var reminderLists: [ReminderList] = []
    /// "볼 캘린더 선택" 체크리스트용 캘린더 목록 — 권한 없으면 빈 배열.
    private(set) var eventCalendars: [EventCalendar] = []

    init(dependencies: Dependencies) {
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.saveAppSettings = dependencies.saveAppSettings
        self.fetchMemoUseCase = dependencies.fetchMemo
        self.saveMemoUseCase = dependencies.saveMemo
        self.refreshLiveActivityLayout = dependencies.refreshLiveActivityLayout
        self.fetchReminderLists = dependencies.fetchReminderLists
        self.fetchCalendars = dependencies.fetchCalendars
        self.analytics = dependencies.analytics
    }

    /// 화면이 나타날 때 — 저장된 설정과 메모 색(배경·글자)을 불러온다.
    func onAppear() async {
        settings = await fetchAppSettings()
        let memo = await fetchMemoUseCase()
        memoColorHex = memo.colorHex
        memoTextColorHex = memo.textColorHex
        memoText = memo.text
        reminderLists = (try? await fetchReminderLists()) ?? []
        eventCalendars = (try? await fetchCalendars()) ?? []
    }

    // MARK: - 변경 (메모리 즉시 반영 + 영속 저장)

    func setColorScheme(_ scheme: AppColorScheme) async {
        analytics.log(.displayModeChanged(mode: scheme.rawValue))
        await update { $0.colorScheme = scheme }
    }

    func setStartTabID(_ id: String) async {
        analytics.log(.startTabChanged(tab: id))
        await update { $0.startTabID = id }
    }

    func setFocusEndSound(_ enabled: Bool) async {
        analytics.log(.focusEndSoundToggled(on: enabled))
        await update { $0.focusEndSound = enabled }
    }

    func setMemoTextSize(_ size: MemoTextSize) async {
        analytics.log(.textSizeChanged(size: size.rawValue))
        await update { $0.memoTextSize = size }
    }

    /// 라이브 항상 표시 마스터 — 다시 켤 때 하위가 전부 꺼진 불능 상태면 셋 다 on으로 리셋한다
    /// (켜자마자 다시 접히는 상태 방지).
    func setLiveAlwaysOn(_ value: Bool) async {
        analytics.log(.alwaysOnToggled(on: value))
        await update {
            $0.liveAlwaysOn = value
            if value, !$0.liveAlwaysOnMemo, !$0.liveAlwaysOnReminder, !$0.liveAlwaysOnSchedule {
                $0.liveAlwaysOnMemo = true
                $0.liveAlwaysOnReminder = true
                $0.liveAlwaysOnSchedule = true
            }
        }
    }

    /// 항상 표시 대상 — 마지막 하나까지 끄면 마스터도 함께 끈다(빈 활성 상태 방지).
    /// 기록은 값이 실제로 바뀔 때만 — 뷰가 같은 값을 재설정하는 경로(범위 변경 등)의 중복을 막는다.
    func setLiveAlwaysOnMemo(_ value: Bool) async {
        if settings.liveAlwaysOnMemo != value {
            analytics.log(.liveItemToggled(kind: "memo", on: value))
        }
        await update {
            $0.liveAlwaysOnMemo = value
            Self.collapseMasterIfAllKindsOff(&$0)
        }
    }

    func setLiveAlwaysOnReminder(_ value: Bool) async {
        if settings.liveAlwaysOnReminder != value {
            analytics.log(.liveItemToggled(kind: "tasks", on: value))
        }
        await update {
            $0.liveAlwaysOnReminder = value
            Self.collapseMasterIfAllKindsOff(&$0)
        }
    }

    func setLiveAlwaysOnSchedule(_ value: Bool) async {
        if settings.liveAlwaysOnSchedule != value {
            analytics.log(.liveItemToggled(kind: "schedule", on: value))
        }
        await update {
            $0.liveAlwaysOnSchedule = value
            Self.collapseMasterIfAllKindsOff(&$0)
        }
    }

    /// 항상 표시 할일 LA의 범위("today"/"scheduled"/"all"/리스트 id).
    /// 기록은 범위가 실제로 바뀔 때만 — off→같은 범위 재선택 경로의 중복을 막는다.
    func setLiveAlwaysOnReminderScopeID(_ id: String) async {
        if settings.liveAlwaysOnReminderScopeID != id {
            analytics.log(.liveScopeChanged(scope: id))
        }
        await update { $0.liveAlwaysOnReminderScopeID = id }
    }

    private static func collapseMasterIfAllKindsOff(_ settings: inout AppSettings) {
        if !settings.liveAlwaysOnMemo, !settings.liveAlwaysOnReminder, !settings.liveAlwaysOnSchedule {
            settings.liveAlwaysOn = false
        }
    }

    /// 할일 탭에 진입했을 때 처음 보여줄 범위("today"/"scheduled"/"all"/리스트 id).
    func setTasksDefaultScopeID(_ id: String) async {
        analytics.log(.tasksDefaultViewChanged(view: id))
        await update { $0.tasksDefaultScopeID = id }
    }

    /// 일정 탭에서 이 캘린더를 보일지(true) 숨길지(false) 설정한다.
    /// 숨김 집합에 넣고 빼는 방식 — 새 캘린더는 목록에 없으므로 기본 표시된다.
    func setCalendarVisible(_ id: String, _ visible: Bool) async {
        analytics.log(.calendarVisibilityToggled(kind: "calendar", on: visible))
        await update {
            if visible { $0.hiddenCalendarIDs.remove(id) }
            else { $0.hiddenCalendarIDs.insert(id) }
        }
    }

    /// 모든 캘린더를 다시 표시 — 숨김 집합을 비운다.
    func showAllCalendars() async {
        analytics.log(.calendarShowAllTapped(kind: "calendar"))
        await update { $0.hiddenCalendarIDs.removeAll() }
    }

    /// 할일 탭에서 이 리스트를 보일지(true) 숨길지(false) 설정한다. 캘린더 숨김과 동일 방식.
    func setReminderListVisible(_ id: String, _ visible: Bool) async {
        analytics.log(.calendarVisibilityToggled(kind: "reminder_list", on: visible))
        await update {
            if visible { $0.hiddenReminderListIDs.remove(id) }
            else { $0.hiddenReminderListIDs.insert(id) }
        }
    }

    /// 모든 미리알림 리스트를 다시 표시 — 숨김 집합을 비운다.
    func showAllReminderLists() async {
        analytics.log(.calendarShowAllTapped(kind: "reminder_list"))
        await update { $0.hiddenReminderListIDs.removeAll() }
    }

    /// 캘린더 표시 토글 — 저장(App Group 미러 포함) 후 켜져 있는 LA를 재게시해 즉시 반영한다.
    func setMemoShowsCalendar(_ value: Bool) async {
        analytics.log(.showCalendarToggled(kind: "memo", on: value))
        await update { $0.memoShowsCalendar = value }
        await refreshLiveActivityLayout()
    }

    func setScheduleShowsCalendar(_ value: Bool) async {
        analytics.log(.showCalendarToggled(kind: "schedule", on: value))
        await update { $0.scheduleShowsCalendar = value }
        await refreshLiveActivityLayout()
    }

    func setReminderShowsCalendar(_ value: Bool) async {
        analytics.log(.showCalendarToggled(kind: "tasks", on: value))
        await update { $0.reminderShowsCalendar = value }
        await refreshLiveActivityLayout()
    }

    /// 메모 LA 카드 배경 색을 바꾼다 — 최신 메모를 다시 읽어 색만 갈아끼우고 저장한다
    /// (텍스트·글자색을 덮어쓰지 않도록 fetch→modify→save). 다음에 메모 화면이 열리면 새 색을 읽는다.
    func setMemoColor(_ hex: String) async {
        // 화면 진입 시 ColorPicker seed가 같은 값을 되돌려 보낸다 — 실제 변경만 기록.
        if hex != memoColorHex {
            analytics.log(.liveColorChanged(kind: "background"))
        }
        var memo = await fetchMemoUseCase()
        memo.colorHex = hex
        await saveMemoUseCase(memo)
        memoColorHex = hex
    }

    /// 메모 LA 카드 글자(폰트) 색을 바꾼다 — fetch→modify→save로 배경색·텍스트는 보존한다.
    func setMemoTextColor(_ hex: String) async {
        // 화면 진입 시 ColorPicker seed가 같은 값을 되돌려 보낸다 — 실제 변경만 기록.
        if hex != memoTextColorHex {
            analytics.log(.liveColorChanged(kind: "font"))
        }
        var memo = await fetchMemoUseCase()
        memo.textColorHex = hex
        await saveMemoUseCase(memo)
        memoTextColorHex = hex
    }

    /// 한 항목을 바꾸고 저장한다 — **최신 저장본을 다시 읽어** 그 위에 변경을 적용한다.
    /// 메모리 스냅샷을 통째로 쓰면 외부 저장(온보딩 완주 플래그·강등 정리)이 onAppear
    /// 이후에 남긴 값을 되돌려버린다(fetch-modify-save, 메모 색 저장과 같은 규칙).
    private func update(_ mutate: (inout AppSettings) -> Void) async {
        var fresh = await fetchAppSettings()
        mutate(&fresh)
        settings = fresh
        await saveAppSettings(fresh)
    }
}
