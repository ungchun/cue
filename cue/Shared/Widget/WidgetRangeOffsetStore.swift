//
//  WidgetRangeOffsetStore.swift
//  cue / Shared
//

import Foundation

/// 좌우 이동이 되는 위젯의 종류 — 이동 단위가 저마다 달라 오프셋도 따로 보관한다.
enum WidgetRangeKind: String, CaseIterable, Sendable {
    /// 월 캘린더 위젯 — 오프셋 단위는 **개월**.
    case month
    /// 3일 위젯 — 오프셋 단위는 **일**(3일씩이 아니라 하루씩 민다).
    case threeDay
    /// 1일 위젯 — 오프셋 단위는 **일**.
    case oneDay

    /// 이동 한계. 위젯은 데이터를 그 자리에서 조회하므로 멀리 갈수록 조회 비용이 커지고,
    /// 무엇보다 "실수로 3년 전에 가 있는" 상태가 되면 되돌아올 방법이 셰브런 연타뿐이다.
    var limit: Int { self == .month ? 12 : 365 }

    /// App Group에 저장할 때 쓰는 키 — rawValue를 그대로 붙인다.
    var offsetKey: String { "cue.widget.offset.\(rawValue).v1" }
    /// 그 오프셋을 **어느 날** 설정했는지. 날이 바뀌면 오프셋을 버리는 근거가 된다.
    var anchorKey: String { "cue.widget.offsetAnchor.\(rawValue).v1" }
}

/// 위젯의 "지금 며칠/몇 달 이동한 상태인지"를 App Group에 들고 다니는 저장소.
///
/// 위젯 익스텐션 프로세스는 수시로 죽었다 살아나므로 이동 상태를 메모리에 둘 수 없다.
/// 그렇다고 영원히 남기면 어제 넘겨본 달이 오늘도 그대로 떠 있게 된다 — 그래서 **오프셋을
/// 설정한 날짜를 함께 저장하고, 날이 바뀌면 0으로 되돌린다**. 위젯의 기본 상태는 언제나 "오늘"이다.
/// `UserDefaults`는 자체로 Sendable이 아니지만 **스레드 안전**이 문서로 보장된다 —
/// 위젯(익스텐션)과 앱이 서로 다른 프로세스에서 동시에 읽고 쓰므로 `@unchecked`로 통과시킨다.
struct WidgetRangeOffsetStore: @unchecked Sendable {

    /// 앱과 위젯 익스텐션이 함께 쓰는 실제 저장소.
    static let shared = WidgetRangeOffsetStore(defaults: SharedAppGroup.defaults)

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// 현재 오프셋. 저장된 날이 오늘이 아니면 0(오늘)으로 본다.
    func offset(for kind: WidgetRangeKind, now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard defaults.object(forKey: kind.offsetKey) != nil,
              isAnchoredToToday(kind, now: now, calendar: calendar) else { return 0 }
        return Self.clamp(defaults.integer(forKey: kind.offsetKey), for: kind)
    }

    /// 오프셋을 `delta`만큼 움직이고 결과를 돌려준다. 셰브런 인텐트가 호출한다.
    @discardableResult
    func shift(
        by delta: Int,
        for kind: WidgetRangeKind,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let next = Self.clamp(offset(for: kind, now: now, calendar: calendar) + delta, for: kind)
        defaults.set(next, forKey: kind.offsetKey)
        defaults.set(anchor(now, calendar), forKey: kind.anchorKey)
        return next
    }

    /// 오늘로 되돌린다 — 앱이 포그라운드로 올라올 때 등에서 명시적으로 초기화할 때.
    func reset(_ kind: WidgetRangeKind) {
        defaults.removeObject(forKey: kind.offsetKey)
        defaults.removeObject(forKey: kind.anchorKey)
    }

    static func clamp(_ offset: Int, for kind: WidgetRangeKind) -> Int {
        max(-kind.limit, min(kind.limit, offset))
    }

    // MARK: - 날짜 앵커

    private func isAnchoredToToday(_ kind: WidgetRangeKind, now: Date, calendar: Calendar) -> Bool {
        guard let stored = defaults.object(forKey: kind.anchorKey) as? Double else { return false }
        return stored == anchor(now, calendar)
    }

    /// 앵커는 그날 자정의 `timeIntervalSince1970` — 시각이 아니라 **날**만 비교하면 되므로.
    private func anchor(_ now: Date, _ calendar: Calendar) -> Double {
        calendar.startOfDay(for: now).timeIntervalSince1970
    }
}
