//
//  EndSampleLiveActivitiesUseCase.swift
//  cue / Domain
//

/// 온보딩 예시 일정·할일 LA 정리 — 포그라운드 복귀 시(온보딩 커버가 없을 때) 호출한다.
///
/// Done 직후가 아니라 **다음 복귀**에 정리하는 이유: Done을 바로 눌러버린 사용자도
/// 다음 잠금에서 3카드 장면을 최소 한 번은 보게 하기 위함. 예시 식별은 마커
/// (`showsCalendarOverride`) 기반이라 실사용 LA를 건드릴 위험이 없다(서비스 구현 참조).
struct EndSampleLiveActivitiesUseCase: Sendable {
    let service: any LiveActivityService

    func callAsFunction() async {
        await service.endSamples()
    }
}
