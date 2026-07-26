//
//  EntitlementSnapshotTests.swift
//  cueTests
//
//  StoreKit 엔타이틀먼트 스냅샷 판정 — "확정 미보유"와 "판정 불가"를 가르는 한 줄이
//  가장 위험한 로직이라(뒤집히면 유료 사용자 강등) 순수 함수로 분리해 고정한다.
//

import Testing
@testable import cue

struct EntitlementSnapshotTests {

    /// 검증된 보유가 있으면 확정 — 일부 검증 실패가 섞여 있어도 보유 1개면 프리미엄 확정.
    @Test func verifiedIDsReturnConfirmedSetEvenWithUnverified() {
        let snapshot = StoreKitPurchaseService.entitlementSnapshot(
            verifiedIDs: ["azhy.cue.premium.monthly"], sawUnverified: true
        )
        #expect(snapshot == ["azhy.cue.premium.monthly"])
    }

    /// 트랜잭션이 아예 없으면 StoreKit의 확정 답변(미보유) — 빈 집합.
    /// (만료·신규 무료 사용자 경로 — 이걸 nil로 바꾸면 만료 강등이 영영 안 돈다.)
    @Test func noTransactionsReturnConfirmedEmpty() {
        let snapshot = StoreKitPurchaseService.entitlementSnapshot(
            verifiedIDs: [], sawUnverified: false
        )
        #expect(snapshot == [])
    }

    /// 검증 실패만 있고 확인 보유가 없으면 판정 불가(nil) — 일시적 검증 실패로
    /// 유료 사용자를 강등시키지 않는다.
    @Test func onlyUnverifiedReturnsNil() {
        let snapshot = StoreKitPurchaseService.entitlementSnapshot(
            verifiedIDs: [], sawUnverified: true
        )
        #expect(snapshot == nil)
    }
}
