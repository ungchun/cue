//
//  DiscardRemindersCacheUseCase.swift
//  cue / Domain
//

import Foundation

/// 할일 조회 캐시를 버린다 — 앱 밖에서 바뀌었을 수 있는 시점(포그라운드 복귀)에 다시 읽기 전에 부른다.
/// 변경 알림이 빠져도 다음 조회가 최신 값을 보게 하기 위해서다.
struct DiscardRemindersCacheUseCase: Sendable {
    private let repository: any RemindersRepository

    init(repository: any RemindersRepository) {
        self.repository = repository
    }

    func callAsFunction() async {
        await repository.discardCache()
    }
}
