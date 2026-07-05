//
//  RefreshLiveActivityLayoutUseCase.swift
//  cue / Domain
//

/// 설정 변경 직후 호출 — 켜져 있는 LA를 현재 상태로 재게시해 즉시 다시 그리게 한다.
/// 위젯이 렌더 시점에 읽는 App Group 미러 설정(캘린더 함께 표시 등)은 재렌더가 있어야
/// 반영되는데, 위젯은 App Group 변경을 스스로 감지하지 못하기 때문이다.
struct RefreshLiveActivityLayoutUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.refreshLayout()
    }
}
