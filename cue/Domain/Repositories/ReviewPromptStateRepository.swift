//
//  ReviewPromptStateRepository.swift
//  cue / Domain
//

/// 리뷰 요청 누적 상태 영속화 — 구현은 Data(UserDefaults/인메모리).
protocol ReviewPromptStateRepository: Sendable {
    func fetch() async -> ReviewPromptState
    func save(_ state: ReviewPromptState) async
}
