//
//  SaveMemoUseCase.swift
//  cue / Domain
//

/// 메모를 영속 저장. ViewModel이 텍스트·색 변경 직후 호출.
struct SaveMemoUseCase: Sendable {
    let repository: any MemoRepository
    func callAsFunction(_ memo: Memo) async {
        await repository.save(memo)
    }
}
