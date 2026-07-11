//
//  PremiumAccess.swift
//  cue / Domain
//

/// 유료(Premium) 접근 전역 스위치 — 결제 도입 전까지의 임시 정책.
///
/// `true`면 모든 프리미엄 기능(라이브 무제한·항상 표시·캘린더·커스텀·집중 세션)을
/// 전 사용자에게 개방한다. StoreKit 도입 시 실제 엔타이틀먼트 조회로 교체한다 —
/// 게이트 코드는 그대로 두고 이 값만 바꾸는 게 계약.
enum PremiumAccess {
    static let isPremium = true
}
