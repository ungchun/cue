//
//  SaveFocusSessionsUseCase.swift
//  cue / Domain
//

/// 집중 세션 프리셋 목록 전체를 영속 저장. ViewModel이 add/update/delete 직후 호출.
struct SaveFocusSessionsUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction(_ sessions: [FocusSession]) async {
        await repository.save(sessions)
    }
}
