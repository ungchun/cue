//
//  ConsiderReviewPromptUseCase.swift
//  cue / Domain
//

import Foundation

/// 라이브 **게시가 성공한 직후** 호출 — 오늘이 처음이면 사용일을 세고, 리뷰를 요청할
/// 시점인지 판정한다. 판정 규칙은 `ReviewPromptPolicy`.
///
/// 호출처가 "게시 성공"으로 한정되는 게 핵심이다. 쿼터 초과(`.denied`)로 막힌 순간은
/// 사용자가 유료 안내를 마주한 직후라 리뷰를 묻기 최악의 타이밍이고, 애초에 그날은
/// 라이브가 뜨지 않았으므로 사용일도 아니다.
///
/// `true`를 돌려준 문턱은 **그 자리에서 기록**한다 — 호출처가 실제로 시스템 프롬프트를
/// 띄웠는지는 알 수 없기 때문(`requestReview`는 iOS가 삼켜도 알려주지 않는다).
/// 요청 "시도"를 기준으로 1회를 보장하는 편이, 안 뜬 걸 감지하려다 매번 다시 묻는 것보다 낫다.
struct ConsiderReviewPromptUseCase: Sendable {
    let repository: any ReviewPromptStateRepository

    /// - Returns: 지금 리뷰를 요청해야 하면 `true`.
    func callAsFunction(now: Date = .now, calendar: Calendar = .current) async -> Bool {
        var state = await repository.fetch()
        let key = ConsumeLiveActivationUseCase.dayKey(for: now, calendar: calendar)

        // 같은 날 두 번째 게시부터는 세지 않는다 — 하루는 몇 번을 띄우든 1일.
        if state.lastDayKey != key {
            state.lastDayKey = key
            state.usageDayCount += 1
        }

        guard let threshold = ReviewPromptPolicy.pendingThreshold(
            dayCount: state.usageDayCount,
            prompted: state.promptedThresholds
        ) else {
            // 날짜만 바뀌었어도 저장은 해야 다음 호출이 같은 날을 다시 세지 않는다.
            await repository.save(state)
            return false
        }

        state.promptedThresholds.insert(threshold)
        await repository.save(state)
        return true
    }
}
