//
//  FocusLiveActivityActionQueue.swift
//  cue / Shared
//

import Foundation

/// 라이브 액티비티 사용자 액션을 widget process → 메인 앱 process로 전달하는 큐.
///
/// **동작 모델**:
/// - widget extension의 App Intent가 `enqueue(_:)`로 사용자 의도를 기록.
/// - 메인 앱은 `scenePhase == .active` 시점에 `drain()`을 호출해 큐를 비우고 순서대로
///   FocusSessionViewModel의 해당 메서드를 실행.
///
/// **race window**: 두 process가 거의 동시에 enqueue/drain을 하면 read-modify-write의
/// 짧은 race가 가능. 잠금화면 탭 — 앱 활성화 사이엔 보통 수십~수백 ms 간격이라 실측상
/// 충돌은 거의 없고, lost write가 발생해도 다음 액션에서 자연 복구(사용자가 다시 탭).
/// 진짜 robust한 동기화는 `NSFileCoordinator`/`@FileSystemSynchronized`까지 가야 하므로
/// 현재 단순 큐로 충분.
///
/// **Sendable**: `UserDefaults`가 Non-Sendable이지만 Apple 문서가 thread-safe임을
/// 명시(Thread Safety section). Swift 6 strict mode가 잡지 못해 `@unchecked Sendable`로
/// 그 보증을 명시한다. 향후 Apple이 어노테이션을 붙이면 제거.
struct FocusLiveActivityActionQueue: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "focus.liveActivity.actionQueue"

    /// 일반 호출자(앱·widget) 양쪽이 사용하는 공유 인스턴스 — App Group suite를 통과.
    static let shared = FocusLiveActivityActionQueue(defaults: SharedAppGroup.defaults)

    /// 테스트는 격리된 `UserDefaults(suiteName:)`를 주입해 서로 데이터 안 보게 한다.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 큐 끝에 액션 추가.
    func enqueue(_ action: FocusLiveActivityAction) {
        var queue = currentQueue()
        queue.append(action)
        store(queue)
    }

    /// 큐를 비우고 들어 있던 액션을 순서대로 반환. 이후 호출은 빈 배열.
    func drain() -> [FocusLiveActivityAction] {
        let queue = currentQueue()
        defaults.removeObject(forKey: key)
        return queue
    }

    /// 큐를 반환 없이 비운다 — 세션 시작/종료 경계에서 **이전 세션의 잔재 액션**을 폐기해,
    /// 다음 세션(특히 복원 세션)에 엉뚱하게 적용되는 걸 막는다.
    func clear() {
        defaults.removeObject(forKey: key)
    }

    // MARK: - 내부

    private func currentQueue() -> [FocusLiveActivityAction] {
        guard let data = defaults.data(forKey: key),
              let queue = try? JSONDecoder().decode([FocusLiveActivityAction].self, from: data)
        else { return [] }
        return queue
    }

    private func store(_ queue: [FocusLiveActivityAction]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        defaults.set(data, forKey: key)
    }
}
