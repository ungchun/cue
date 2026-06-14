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
/// 세션 프리셋 목록과 "마지막으로 선택한 세션"은 모두 영속화된다 — 앱 재시작 후에도
/// 같은 세션이 메인 화면에 자동으로 떠 있다. 진행 중인 세션 자체는 영속화하지 않는다.
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
    private let fetchSelectedFocusSessionID: FetchSelectedFocusSessionIDUseCase
    private let saveSelectedFocusSessionID: SaveSelectedFocusSessionIDUseCase
    private let startLiveActivity: StartFocusLiveActivityUseCase
    private let updateLiveActivity: UpdateFocusLiveActivityUseCase
    private let endLiveActivity: EndFocusLiveActivityUseCase

    init(dependencies: Dependencies) {
        self.scheduler = dependencies.focusNotifications
        self.fetchFocusSessions = dependencies.fetchFocusSessions
        self.saveFocusSessions = dependencies.saveFocusSessions
        self.fetchSelectedFocusSessionID = dependencies.fetchSelectedFocusSessionID
        self.saveSelectedFocusSessionID = dependencies.saveSelectedFocusSessionID
        self.startLiveActivity = dependencies.startFocusLiveActivity
        self.updateLiveActivity = dependencies.updateFocusLiveActivity
        self.endLiveActivity = dependencies.endFocusLiveActivity
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

    /// 화면이 처음 나타날 때 한 번 호출 — 알림 권한 prompt + 저장된 세션·선택 복원.
    ///
    /// 복원 정책:
    /// - 저장된 id가 현재 sessions에 존재 → 그 세션을 선택.
    /// - 저장된 id가 없거나 사라졌는데 sessions가 비어 있지 않으면 → 첫 번째를 자동 선택.
    ///   ("선택 없음" 상태를 보여주는 것보다, 사용자가 만들어둔 첫 프리셋을 띄우는 게 자연스럽다.)
    /// - sessions 자체가 비어 있으면 → nil (placeholder + 기본 설정).
    /// 사용자가 한 번이라도 진행 중인(`session != nil`) 상태에서 onAppear가 다시 불릴
    /// 일은 없지만, 만약 그렇다면 그 세션을 깨지 않도록 복원은 idle에서만 수행한다.
    func onAppear() async {
        await scheduler.requestAuthorization()
        sessions = await fetchFocusSessions()
        guard session == nil else { return }
        let storedID = await fetchSelectedFocusSessionID()
        if let storedID, sessions.contains(where: { $0.id == storedID }) {
            selectedSessionID = storedID
        } else if let first = sessions.first {
            selectedSessionID = first.id
            // 저장값이 비어 있거나 무효였던 경우 → 첫 항목을 새 영속값으로 박는다.
            // 다음 onAppear에서도 일관되게 같은 세션이 떠 있게 된다.
            persistSelectedID(first.id)
        } else {
            selectedSessionID = nil
        }
    }

    /// 메인 화면의 ▶ 버튼이 호출 — 선택된 세션(또는 기본값)으로 상태머신을 만든다.
    /// 이미 진행 중이면 무시. 라이브 액티비티 hooks를 함께 주입해 — 세션 자체가 phase
    /// 전환·pause/resume·완료 시점에 LA `update`/`end`를 호출한다(cue 컨셉: 종료 상태가
    /// 아니면 라이브 액티비티 활성).
    func start() {
        guard session == nil else { return }
        let hooks = FocusSessionViewModel.LiveActivityHooks(
            sessionID: UUID(),
            // 세션 선택 없으면 앱 화면 titleHeader와 동일하게 앱 이름 "Cue"로 — LA 상단도 일치.
            sessionTitle: selectedSession?.title ?? "Cue",
            colorHex: selectedSession?.colorHex,
            start: startLiveActivity,
            update: updateLiveActivity,
            end: endLiveActivity
        )
        session = FocusSessionViewModel(
            settings: displayedSettings,
            scheduler: scheduler,
            liveActivity: hooks
        )
    }

    /// 진행 중인 세션을 중단·정리한다. 종료 버튼/자동 완료에서 호출.
    func stopSession() {
        session?.abort()
        session = nil
    }

    /// 잠금화면·Dynamic Island의 App Intent가 큐에 enqueue한 액션들을 받아 ViewModel에
    /// 반영한다. 메인 앱이 `.active`로 들어올 때마다 호출 — 빈 배열이면 no-op.
    ///
    /// 액션 → 메서드 매핑(누른 시각 `at`을 그대로 넘겨 drain 지연만큼의 시간 누수 방지):
    /// - `.pause(at:)` → `session?.pause(at:)` (idempotent — 이미 paused면 무시됨)
    /// - `.resume(at:)` → `session?.resume(at:)` (idempotent — 진행 중이면 무시됨)
    /// - `.end` → `stopSession()` (이미 nil이면 no-op)
    ///
    /// `FocusSessionViewModel`의 pause/resume이 LA `update`를 다시 보내므로 widget이 미리
    /// 토글해둔 `pauseTime` 위에 정확한 `phaseStartDate`·`phaseEndDate`가 덮여 일관성 회복.
    func handleLiveActivityActions(_ actions: [FocusLiveActivityAction]) {
        for action in actions {
            switch action {
            case .pause(let at):
                session?.pause(at: at)
            case .resume(let at):
                session?.resume(at: at)
            case .end:
                stopSession()
            }
        }
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

    /// 세션을 목록에서 제거. 삭제 대상이 선택된 세션이면 선택도 해제하고 영속값도 nil로.
    func deleteSession(id: UUID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = nil
            persistSelectedID(nil)
        }
        persist()
    }

    /// 현재 `sessions`를 영속 저장소에 비동기 dispatch — 호출자는 결과를 기다리지 않는다.
    /// 직렬화 실패는 repository 내부에서 무시된다(다음 변경 때 다시 시도).
    private func persist() {
        let snapshot = sessions
        Task { await saveFocusSessions(snapshot) }
    }

    /// 선택된 세션 id를 영속 저장소에 비동기 dispatch. sessions 영속화와 같은 fire-and-forget.
    private func persistSelectedID(_ id: UUID?) {
        Task { await saveSelectedFocusSessionID(id) }
    }

    /// 메인 화면에 띄울 세션을 고른다. 없는 id를 줘도 그대로 둠(다음 lookup에서 nil 폴백).
    /// 변경된 id는 즉시 영속화 — 앱을 끄고 다시 켜도 같은 세션이 떠 있는다.
    func selectSession(id: UUID) {
        selectedSessionID = id
        persistSelectedID(id)
    }
}
