//
//  FetchMemoUseCase.swift
//  cue / Domain
//

/// 저장된 메모를 불러온다. ViewModel이 onAppear 시 호출. 없으면 `Memo.default`.
struct FetchMemoUseCase: Sendable {
    let repository: any MemoRepository
    func callAsFunction() async -> Memo {
        await repository.fetch()
    }
}
