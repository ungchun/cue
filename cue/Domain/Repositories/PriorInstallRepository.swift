//
//  PriorInstallRepository.swift
//  cue / Domain
//

import Foundation

/// 기존 설치 흔적 조회 — 온보딩이 없던 구버전을 쓰던 사용자인지 판별한다.
/// 앱 업데이트로 온보딩이 처음 생겼을 때, 기존 사용자에게 온보딩을 띄우지 않기 위함.
/// 동기 조회 — 앱 시작 직후(스냅샷 프리페치가 저장물을 쓰기 **전에**) 읽어야 해서
/// async 경합 없이 즉시 답해야 한다.
protocol PriorInstallRepository: Sendable {
    func hasPriorUsageEvidence() -> Bool
}
