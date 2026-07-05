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

    /// 현재 설정. View는 읽기만 하고, 변경은 아래 `set...` 메서드로.
    private(set) var settings: AppSettings = .default
    /// 메모 라이브 액티비티 카드 배경 색(hex). 설정의 일부가 아니라 단일 `Memo`의 속성을
    /// 여기서 편집한다 — 메모 화면의 색 선택 UI가 제거되어 설정 탭이 유일한 색 편집면이다.
    /// 출처는 `Memo.colorHex`(LA ContentState로 위젯에 그대로 실린다).
    private(set) var memoColorHex: String = Memo.default.colorHex
    /// 메모 라이브 액티비티 카드 글자(폰트) 색(hex). 출처는 `Memo.textColorHex`.
    private(set) var memoTextColorHex: String = Memo.default.textColorHex

    init(dependencies: Dependencies) {
        self.fetchAppSettings = dependencies.fetchAppSettings
        self.saveAppSettings = dependencies.saveAppSettings
        self.fetchMemoUseCase = dependencies.fetchMemo
        self.saveMemoUseCase = dependencies.saveMemo
    }

    /// 화면이 나타날 때 — 저장된 설정과 메모 색(배경·글자)을 불러온다.
    func onAppear() async {
        settings = await fetchAppSettings()
        let memo = await fetchMemoUseCase()
        memoColorHex = memo.colorHex
        memoTextColorHex = memo.textColorHex
    }

    // MARK: - 변경 (메모리 즉시 반영 + 영속 저장)

    func setColorScheme(_ scheme: AppColorScheme) async {
        await update { $0.colorScheme = scheme }
    }

    func setStartTabID(_ id: String) async {
        await update { $0.startTabID = id }
    }

    func setFocusEndSound(_ enabled: Bool) async {
        await update { $0.focusEndSound = enabled }
    }

    func setMemoTextSize(_ size: MemoTextSize) async {
        await update { $0.memoTextSize = size }
    }

    func setMemoShowsCalendar(_ value: Bool) async {
        await update { $0.memoShowsCalendar = value }
    }

    func setScheduleShowsCalendar(_ value: Bool) async {
        await update { $0.scheduleShowsCalendar = value }
    }

    /// 메모 LA 카드 배경 색을 바꾼다 — 최신 메모를 다시 읽어 색만 갈아끼우고 저장한다
    /// (텍스트·글자색을 덮어쓰지 않도록 fetch→modify→save). 다음에 메모 화면이 열리면 새 색을 읽는다.
    func setMemoColor(_ hex: String) async {
        var memo = await fetchMemoUseCase()
        memo.colorHex = hex
        await saveMemoUseCase(memo)
        memoColorHex = hex
    }

    /// 메모 LA 카드 글자(폰트) 색을 바꾼다 — fetch→modify→save로 배경색·텍스트는 보존한다.
    func setMemoTextColor(_ hex: String) async {
        var memo = await fetchMemoUseCase()
        memo.textColorHex = hex
        await saveMemoUseCase(memo)
        memoTextColorHex = hex
    }

    /// 한 항목을 바꾸고 통째로 저장한다 — 설정이 하나뿐이라 매 변경마다 전체 write가 가볍다.
    private func update(_ mutate: (inout AppSettings) -> Void) async {
        mutate(&settings)
        await saveAppSettings(settings)
    }
}
