//
//  FetchSelectedFocusSessionIDUseCase.swift
//  cue / Domain
//

import Foundation

/// 마지막으로 선택된 집중 세션의 id를 불러온다. ViewModel이 첫 로드(onAppear) 시 호출해
/// 앱 재시작 후에도 같은 세션을 메인 화면에 띄운다. 저장값이 없으면 nil.
struct FetchSelectedFocusSessionIDUseCase: Sendable {
    let repository: any FocusSessionsRepository
    func callAsFunction() async -> UUID? {
        await repository.fetchSelectedSessionID()
    }
}
