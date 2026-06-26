//
//  EndMemoLiveActivityUseCase.swift
//  cue / Domain
//

/// 메모 라이브 액티비티 즉시 종료. dismissalPolicy는 구현이 `.immediate` 적용.
struct EndMemoLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.endMemo()
    }
}
