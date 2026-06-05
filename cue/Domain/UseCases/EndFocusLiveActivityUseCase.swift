//
//  EndFocusLiveActivityUseCase.swift
//  cue / Domain
//

/// 집중 라이브 액티비티 종료. 구현이 완료 결과를 60초간 보여주고 dismiss하는 정책.
struct EndFocusLiveActivityUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.endFocus()
    }
}
