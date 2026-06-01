//
//  ObserveEventsChangesUseCase.swift
//  cue / Domain
//

import Foundation

/// 캘린더 이벤트 저장소의 변경 신호 스트림을 노출한다. 값을 싣지 않는 신호 전용 —
/// 구독자는 신호가 올 때마다 자기 fetch를 다시 한다. 첫 진입에 fetch한 후 이 스트림을
/// 구독해 두면 외부(캘린더 앱) 변경에만 reload된다 — 매 화면 진입마다 다시 fetch할 필요 없음.
struct ObserveEventsChangesUseCase: Sendable {
    private let repository: any EventsRepository

    init(repository: any EventsRepository) {
        self.repository = repository
    }

    func callAsFunction() -> AsyncStream<Void> {
        repository.changes()
    }
}
