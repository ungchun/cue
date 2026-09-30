//
//  SerialGate.swift
//  cue / Core
//

import Foundation

/// 비동기 작업을 **한 번에 하나씩, 들어온 순서대로** 통과시키는 게이트.
///
/// **왜 필요한가** — actor는 `await` 지점에서 재진입된다. "확인 → await → 행동" 형태의
/// 작업은 actor 안에 있어도 서로 끼어들어, 앞 작업이 아직 만들지 않은 것을 뒤 작업이
/// 못 본 채 같은 일을 또 한다. 게이트는 작업 전체를 하나의 임계 구역으로 묶는다.
///
/// 실제 증상: 콜드런치에 일정 라이브 게시가 겹쳐 들어와 각자 "전부 종료 → request"를
/// 돌려 카드가 최대 4개 쌓였다(2026-09-30 재보고).
///
/// **재진입 금지** — `run` 안에서 같은 게이트의 `run`을 다시 부르면 영원히 기다린다.
actor SerialGate {

    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// 앞선 작업이 모두 끝난 뒤 `operation`을 실행한다. throw해도 게이트는 풀린다.
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await enter()
        defer { leave() }
        return try await operation()
    }

    private func enter() async {
        guard isBusy else {
            isBusy = true
            return
        }
        // 깨어날 때는 앞 작업이 점유를 **넘겨준** 상태다 — `isBusy`는 계속 true.
        await withCheckedContinuation { waiters.append($0) }
    }

    private func leave() {
        // 대기자가 있으면 점유를 풀지 않고 그대로 넘긴다 — 풀었다가 다시 잡으면 그 틈에
        // 새로 들어온 작업이 줄을 새치기한다.
        guard !waiters.isEmpty else {
            isBusy = false
            return
        }
        waiters.removeFirst().resume()
    }
}
