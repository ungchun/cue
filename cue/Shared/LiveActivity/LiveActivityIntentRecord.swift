//
//  LiveActivityIntentRecord.swift
//  cue / Shared
//

import Foundation

/// **사용자가 켜둔 채로 두었다**는 사실의 기록.
///
/// ActivityKit은 라이브가 왜 사라졌는지 알려주지 않는다 — 사용자가 직접 껐든, 시스템이
/// 8시간 한도로 죽였든 똑같이 "없음"이다. 그래서 이 둘을 구분하려면 앱이 직접 기록해야 한다.
///
/// - 켤 때 기록하고, **직접 끌 때** 지운다.
/// - 시스템이 8시간으로 죽이는 경로는 앱을 거치지 않으므로 기록이 **남는다**.
///
/// 그래서 "기록은 있는데 실제 라이브는 없다" = 시스템이 죽였다 = 되살릴 대상이다.
/// 단축어 자동화가 판단의 근거로 삼는 값이 이것이다.
///
/// App Group에 두는 이유는 인텐트가 앱과 다른 실행 맥락에서 깨어날 수 있기 때문이다.
///
/// `LiveActivityKind.focus`는 여기 기록되지 않는다 — 집중은 AlarmKit으로 이관돼
/// `ActivityKitLiveActivityService`를 거치지 않고, 8시간 한도의 대상도 아니다.
enum LiveActivityIntentRecord {

    private static let key = "cue.la.userWantsLive.v1"

    /// 사용자가 켜둔 채로 둔 라이브 종류들.
    static func wanted(in store: UserDefaults = SharedAppGroup.defaults) -> Set<LiveActivityKind> {
        let raw = store.stringArray(forKey: key) ?? []
        return Set(raw.compactMap(LiveActivityKind.init(rawValue:)))
    }

    /// 라이브를 켰다 — 자동화가 되살릴 대상에 넣는다.
    static func markStarted(_ kind: LiveActivityKind, in store: UserDefaults = SharedAppGroup.defaults) {
        var next = wanted(in: store)
        next.insert(kind)
        save(next, in: store)
    }

    /// 사용자가 **직접** 껐다 — 되살릴 대상에서 뺀다.
    ///
    /// 시스템의 8시간 종료에서는 이 함수가 불리지 않아야 한다. 불리면 자동화가 되살릴
    /// 근거를 잃어 기능 자체가 무력화된다.
    static func markEnded(_ kind: LiveActivityKind, in store: UserDefaults = SharedAppGroup.defaults) {
        var next = wanted(in: store)
        next.remove(kind)
        save(next, in: store)
    }

    private static func save(_ kinds: Set<LiveActivityKind>, in store: UserDefaults) {
        // 정렬해 저장 — 순서가 흔들리면 값이 바뀐 것처럼 보여 디버깅이 어려워진다.
        store.set(kinds.map(\.rawValue).sorted(), forKey: key)
    }
}
