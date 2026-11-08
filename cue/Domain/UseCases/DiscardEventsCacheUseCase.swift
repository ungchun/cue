//
//  DiscardEventsCacheUseCase.swift
//  cue / Domain
//

import Foundation

/// 이벤트 조회 캐시를 버린다 — 앱이 직접 쓴 직후 다시 읽기 전에 부른다.
/// 변경 알림이 빠져도 다음 조회가 방금 쓴 값을 보게 하기 위해서다.
struct DiscardEventsCacheUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction() async {
        await repository.discardCache()
    }
}
