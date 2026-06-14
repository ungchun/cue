//
//  BackgroundAudioKeeping.swift
//  cue / Domain
//

import Foundation

/// 진행 중인 집중 세션 동안 백그라운드 오디오로 앱을 **깨어 있게 유지**하는 추상화.
///
/// Live Activity는 앱이 닫혀/중단된 동안 스스로 단계를 전환하지 못한다(OS 제약 — 푸시 서버
/// 필요). 백그라운드 오디오를 재생하면 OS가 앱을 재우지 않아, 잠금/백그라운드 상태에서도
/// 타이머(`Timer.publish`)가 계속 돌며 단계 전환·LA 갱신이 작동한다. **강제 종료(kill) 시엔
/// 중단**되며 그땐 재오픈 시 복원으로 수렴한다.
///
/// 현재 구현은 **무음** keep-alive다. 추후 집중 사운드(화이트노이즈 등) 재생으로 교체해도
/// 호출처(세션 시작/종료)는 그대로 둔다 — 그래서 인터페이스는 `start`/`stop`만 노출한다.
protocol BackgroundAudioKeeping: Sendable {
    /// 세션 시작·복원 시 호출 — 오디오 세션 활성 + 재생 시작.
    @MainActor func start()
    /// 세션 종료·완료 시 호출 — 재생 중지 + 오디오 세션 비활성.
    @MainActor func stop()
}
