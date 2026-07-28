//
//  InMemoryReviewPromptStateRepository.swift
//  cue / Data
//

/// 테스트·Preview용 인메모리 리뷰 상태 저장소.
actor InMemoryReviewPromptStateRepository: ReviewPromptStateRepository {
    private var storage: ReviewPromptState

    init(storage: ReviewPromptState = .empty) {
        self.storage = storage
    }

    func fetch() async -> ReviewPromptState {
        storage
    }

    func save(_ state: ReviewPromptState) async {
        storage = state
    }
}
