//
//  EndSampleLiveActivitiesUseCase.swift
//  cue / Domain
//

/// 온보딩 예시 일정·할일 LA 정리 — **다음 앱 실행** 시(온보딩을 띄우지 않는 실행) 호출한다.
///
/// Done 직후·포그라운드 복귀가 아니라 다음 실행에 정리하는 이유: Done을 바로 눌러도
/// 그 세션 내내 3카드 장면이 유지돼 최소 한 번은 보게 되고, 복귀 시점 정리는 Face ID가
/// 잠금화면을 건너뛰어 게시 직후 지워버리는 문제가 있었다. 예시 식별은 마커
/// (`isSample`) 기반이라 실사용 LA를 건드릴 위험이 없다(서비스 구현 참조).
struct EndSampleLiveActivitiesUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.endSamples()
    }
}
