//
//  FetchFocusSessionsUseCase.swift
//  cue / Domain
//

/// 저장된 집중 세션 프리셋 목록을 불러온다. ViewModel이 첫 로드(onAppear) 시 호출.
struct FetchFocusSessionsUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction() async -> [FocusSession] {
        await repository.fetchAll()
    }
}
