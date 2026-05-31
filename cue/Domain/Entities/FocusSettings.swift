//
//  FocusSettings.swift
//  cue / Domain
//

import Foundation

/// 집중 탭의 세션 설정 — 한 세션을 시작할 때 ViewModel에 전달되어 그 세션의 전체 흐름
/// (집중·휴식 시간, 반복 여부, 사이클 수)을 결정한다.
///
/// 단위는 초(`TimeInterval`). UI는 분 단위로 보여주지만 도메인은 초로 통일해
/// 타이머 tick과의 환산을 단순하게 둔다.
struct FocusSettings: Equatable, Sendable {
    /// 집중 단계 한 번의 길이.
    var focusDuration: TimeInterval
    /// 휴식 단계 한 번의 길이. `isRepeating == false`면 무시된다(휴식 없음).
    var restDuration: TimeInterval
    /// 반복 여부. false면 집중 한 번만 돌고 끝난다(휴식·다음 사이클 없음).
    var isRepeating: Bool
    /// 반복일 때 돌릴 집중 횟수. `isRepeating == false`면 무시. 1 이상.
    var cycleCount: Int

    /// 신규 세션의 기본값 — 표준 뽀모도로(25/5분) + 4 사이클 반복.
    static let `default` = FocusSettings(
        focusDuration: 25 * 60,
        restDuration: 5 * 60,
        isRepeating: true,
        cycleCount: 4
    )

    /// 실제 세션이 돌릴 총 집중 횟수.
    /// `isRepeating == false`면 1, true면 `cycleCount`.
    /// 세션 ViewModel이 종료 판정과 진행 표시(`1 / N`)에 모두 사용한다.
    var totalCycles: Int {
        isRepeating ? max(1, cycleCount) : 1
    }
}
