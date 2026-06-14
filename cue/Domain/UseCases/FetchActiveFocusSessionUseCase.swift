//
//  FetchActiveFocusSessionUseCase.swift
//  cue / Domain
//

import Foundation

/// 진행 중이던 집중 세션 스냅샷을 불러온다. ViewModel이 첫 로드(onAppear) 시 호출해
/// 앱 강제 종료 후 재실행에도 세션을 복원한다. 저장된 진행 중 세션이 없으면 nil.
struct FetchActiveFocusSessionUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction() async -> ActiveFocusSessionSnapshot? {
        await repository.fetchActiveSession()
    }
}
