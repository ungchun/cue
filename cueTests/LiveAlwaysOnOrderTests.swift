//
//  LiveAlwaysOnOrderTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

/// 항상 표시 라이브의 게시 순서 — 저장본을 게시 경로가 쓸 수 있게 정제하는 규칙.
///
/// "먼저 게시한 라이브가 잠금화면 위"이므로(실기기 검증) 이 배열의 순서가 곧 잠금화면
/// 순서다. 저장본은 사용자 편집·구버전·미래 버전을 거치며 어긋날 수 있어, 게시 직전에
/// 항상 이 정제를 거친다.
struct LiveAlwaysOnOrderTests {

    @Test func defaultOrderMatchesLegacyPublishOrder() {
        // 필드가 없던 시절의 실제 게시 순서(메모→할일→일정)가 기본값 — 업데이트로
        // 기존 사용자의 잠금화면 순서가 소리 없이 바뀌면 안 된다.
        #expect(AppSettings.default.liveAlwaysOnOrder == [.memo, .reminder, .schedule])
    }

    @Test func validOrderPassesThrough() {
        let order = AppSettings.resolveLiveOrder([.schedule, .memo, .reminder])
        #expect(order == [.schedule, .memo, .reminder])
    }

    @Test func missingKindsAreAppendedInDefaultOrder() {
        // 미래 버전이 종류를 추가해도 옛 저장본에서 그 종류가 사라지지 않아야 한다.
        #expect(AppSettings.resolveLiveOrder([.schedule]) == [.schedule, .memo, .reminder])
        #expect(AppSettings.resolveLiveOrder([]) == [.memo, .reminder, .schedule])
    }

    @Test func focusIsNeverInTheOrder() {
        // 집중은 AlarmKit 엔진의 라이브라 항상 표시 대상이 아니다.
        #expect(AppSettings.resolveLiveOrder([.focus, .memo, .reminder, .schedule])
                == [.memo, .reminder, .schedule])
    }

    @Test func duplicatesKeepFirstAppearance() {
        // 손상된 저장본이 같은 종류를 두 번 게시하게 만들면 안 된다.
        #expect(AppSettings.resolveLiveOrder([.memo, .memo, .schedule, .reminder, .schedule])
                == [.memo, .schedule, .reminder])
    }

    /// 필드가 없던 옛 저장본은 기본 순서로 채워 디코딩된다(전방 호환).
    @Test func decodesLegacySettingsWithDefaultOrder() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(settings.liveAlwaysOnOrder == [.memo, .reminder, .schedule])
    }

    /// 사용자가 바꾼 순서는 저장·복원을 오가도 유지된다.
    @Test func orderRoundTripsThroughCoding() throws {
        var settings = AppSettings.default
        settings.liveAlwaysOnOrder = [.schedule, .reminder, .memo]
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(decoded.liveAlwaysOnOrder == [.schedule, .reminder, .memo])
    }
}
