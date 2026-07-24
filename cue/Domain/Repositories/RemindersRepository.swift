//
//  RemindersRepository.swift
//  cue / Domain
//

import Foundation

/// iOS "미리 알림" 저장소 추상화 — Domain이 소유하는 프로토콜. 구현은 Data 계층(EventKit).
///
/// Domain은 EventKit 같은 세부 기술을 알지 못한다. 이 경계 덕분에
/// 저장 방식이 바뀌어도 Domain/Presentation은 영향받지 않는다.
protocol RemindersRepository: Sendable {
    /// 접근 권한을 요청한다 (필요 시 시스템 프롬프트). 결과 상태를 돌려준다.
    func requestAccess() async -> RemindersAccess
    /// 프롬프트 없이 현재 권한 상태만 읽는다 — 앱 시작 프리페치가 권한 팝업을
    /// 유발하지 않기 위한 경로. 이미 허용된 경우에만 프리페치가 진행된다.
    func currentAccess() async -> RemindersAccess
    /// 모든 미리 알림 리스트.
    func fetchLists() async throws -> [ReminderList]
    /// 모든 리스트의 미리 알림 항목 전체.
    func fetchReminders() async throws -> [Reminder]
    /// 항목의 완료 상태를 설정한다.
    func setCompleted(_ completed: Bool, reminderID: String) async throws
    /// 리스트에 새 항목을 추가하고, 저장된 항목(실제 id 포함)을 돌려준다 — 호출자가 재조회를
    /// 기다리지 않고 로컬 목록에 즉시 반영(낙관적 갱신)할 수 있게. 저장 시 행 깜빡임 제거의 근간.
    /// `notes`가 nil이면 메모 없이 만든다.
    /// `dueDate`가 nil이면 마감일 없이, `includesTime`이 false면 시간 없는(종일) 마감으로 만든다.
    @discardableResult
    func addReminder(
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool,
        toListID listID: String
    ) async throws -> Reminder
    /// 기존 항목의 제목·메모·마감일을 갱신하고, 갱신된 항목을 돌려준다 — 같은 id의 항목을
    /// 로컬에서 in-place 치환하기 위함(add와 같은 낙관적 갱신 계약).
    /// `notes`가 nil이면 메모를 비우고, `dueDate`가 nil이면 마감일을 지운다.
    /// `includesTime`은 종일/시각 구분을 결정한다 (시각이면 EventKit 알람도 함께 갱신).
    @discardableResult
    func updateReminder(
        reminderID: String,
        title: String,
        notes: String?,
        dueDate: Date?,
        includesTime: Bool
    ) async throws -> Reminder
    /// 항목을 삭제한다.
    func deleteReminder(reminderID: String) async throws
    /// 항목을 다른 리스트로 옮긴다 (전체 탭 섹션 간 드래그). EventKit에선 calendar 교체.
    func moveReminder(reminderID: String, toListID listID: String) async throws

    /// 새 리스트(섹션)를 만든다. 만들어진 리스트의 ID를 돌려준다 — 호출자가 곧장 선택하도록.
    /// `colorHex`가 nil이면 시스템 기본 색.
    func addList(title: String, colorHex: String?) async throws -> String
    /// 기존 리스트의 이름·색을 갱신한다.
    func updateList(listID: String, title: String, colorHex: String?) async throws
    /// 리스트를 삭제한다 — 안에 있는 모든 항목도 함께 제거된다 (EventKit 동작).
    func deleteList(listID: String) async throws

    /// 외부에서 미리알림이 변경됐다는 신호 스트림 — 값은 싣지 않고, 구독자는 신호가 오면
    /// `fetchLists` / `fetchReminders`로 다시 가져온다. EventKit 구현은 `EKEventStoreChanged`
    /// 노티를 노출. 구독은 호출 측의 `Task`에 묶여 cancel 시 자동 종료된다.
    func changes() -> AsyncStream<Void>
}

extension RemindersRepository {
    /// 기본 구현 — 프롬프트 없는 상태 조회가 없는 구현(테스트 더블 등)은 requestAccess로
    /// 폴백한다. 실 EventKit 구현은 반드시 상태-전용 조회로 오버라이드한다.
    func currentAccess() async -> RemindersAccess { await requestAccess() }
}
