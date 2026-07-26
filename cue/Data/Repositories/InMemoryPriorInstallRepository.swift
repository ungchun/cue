//
//  InMemoryPriorInstallRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 — 흔적 유무를 고정값으로 돌려준다(기본 신규 설치).
struct InMemoryPriorInstallRepository: PriorInstallRepository {
    var evidence = false

    func hasPriorUsageEvidence() -> Bool { evidence }
}
