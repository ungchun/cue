//
//  FocusViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 집중 탭의 ViewModel — 저장된 세션 프리셋 목록(`sessions`)을 들고 있고, 사용자가
/// 목록에서 하나를 고르면 그 세션을 메인 화면 ring·타이틀에 반영한다. "시작"이 눌리면
/// 선택된 세션의 설정으로 상태머신(`FocusSessionViewModel`)을 만들어 같은 메인 화면 안에서
/// 타이머를 돌린다.
///
/// 영속화는 다음 사이클 — 현재는 메모리에만 보관. 앱을 재시작하면 비워진다.
@MainActor
@Observable
final class FocusViewModel {
    /// 저장된 세션 프리셋. 사용자가 +로 만들고 수정/삭제한다.
    private(set) var sessions: [FocusSession] = []
    /// 메인 화면이 보여줄 세션. nil이면 기본값(25/5분·4 사이클)으로 폴백.
    var selectedSessionID: UUID?
    /// 진행 중인 세션 상태머신. nil이면 idle.
    var session: FocusSessionViewModel?

    private let scheduler: any FocusNotificationScheduling
    private let fetchFocusSessions: FetchFocusSessionsUseCase
    private let saveFocusSessions: SaveFocusSessionsUseCase

    init(dependencies: Dependencies) {
        self.scheduler = dependencies.focusNotifications
        self.fetchFocusSessions = dependencies.fetchFocusSessions
        self.saveFocusSessions = dependencies.saveFocusSessions
    }

    /// 현재 선택된 세션. id로 매번 lookup해 update/delete와 자연스럽게 동기화된다.
    var selectedSession: FocusSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first(where: { $0.id == id })
    }

    /// 메인 ring·타이틀이 사용할 설정. 선택 없으면 `FocusSettings.default`.
    var displayedSettings: FocusSettings {
        selectedSession?.settings ?? .default
    }

    /// 화면이 처음 나타날 때 한 번 호출 — 알림 권한 prompt + 저장된 세션 로드.
    func onAppear() async {
        await scheduler.requestAuthorization()
        sessions = await fetchFocusSessions()
    }

    /// 메인 화면의 ▶ 버튼이 호출 — 선택된 세션(또는 기본값)으로 상태머신을 만든다.
    /// 이미 진행 중이면 무시.
    func start() {
        guard session == nil else { return }
        session = FocusSessionViewModel(settings: displayedSettings, scheduler: scheduler)
    }

    /// 진행 중인 세션을 중단·정리한다. 종료 버튼/자동 완료에서 호출.
    func stopSession() {
        session?.abort()
        session = nil
    }

    // MARK: - 세션 프리셋 CRUD

    /// 세션을 새로 만들어 목록 끝에 추가하고, 생성된 세션을 반환한다.
    /// 메모리 갱신 즉시 영속 저장 dispatch — UserDefaults 쓰기는 빠르지만 fire-and-forget으로
    /// UI 흐름을 막지 않는다.
    @discardableResult
    func addSession(title: String, settings: FocusSettings, colorHex: String) -> FocusSession {
        let new = FocusSession(id: UUID(), title: title, settings: settings, colorHex: colorHex)
        sessions.append(new)
        persist()
        return new
    }

    /// 같은 id의 세션을 새 title·settings·colorHex로 덮어쓴다. 못 찾으면 no-op.
    func updateSession(id: UUID, title: String, settings: FocusSettings, colorHex: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index] = FocusSession(id: id, title: title, settings: settings, colorHex: colorHex)
        persist()
    }

    /// 세션을 목록에서 제거. 삭제 대상이 선택된 세션이면 선택도 해제한다.
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id { selectedSessionID = nil }
        persist()
    }

    /// 현재 `sessions`를 영속 저장소에 비동기 dispatch — 호출자는 결과를 기다리지 않는다.
    /// 직렬화 실패는 repository 내부에서 무시된다(다음 변경 때 다시 시도).
    private func persist() {
        let snapshot = sessions
        Task { await saveFocusSessions(snapshot) }
    }

    /// 메인 화면에 띄울 세션을 고른다. 없는 id를 줘도 그대로 둠(다음 lookup에서 nil 폴백).
    func selectSession(id: UUID) {
        selectedSessionID = id
    }
}
