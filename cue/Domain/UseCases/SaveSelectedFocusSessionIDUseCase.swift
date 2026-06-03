//
//  SaveSelectedFocusSessionIDUseCase.swift
//  cue / Domain
//

import Foundation

/// 마지막으로 선택된 집중 세션 id를 영속 저장. ViewModel이 선택을 바꾸거나 선택된
/// 세션을 삭제할 때 호출한다. nil을 주면 "선택 없음"으로 기록.
struct SaveSelectedFocusSessionIDUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction(_ id: UUID?) async {
        await repository.saveSelectedSessionID(id)
    }
}
