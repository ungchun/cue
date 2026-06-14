//
//  FocusAlarmPlan.swift
//  cue / Shared
//

import Foundation

// MARK: - 타깃 멤버십
//
// 메인 앱이 세션 시작 시 저장하고, 위젯 익스텐션의 체이닝 인텐트(`FocusAlarmAdvanceIntent`)가 다음
// 단계를 예약할 때 읽는다 — 두 프로세스가 App Group으로 공유. pbxproj exception으로 익스텐션에도 포함.

/// 진행 중인 집중 세션의 설정 스냅샷 — App Group에 저장해 메인 앱과 인텐트가 공유한다.
///
/// 단계별 알람을 하나씩 예약·체이닝하는데, 다음 단계를 예약하는 주체가 메인 앱일 수도(포그라운드
/// 자동 전환) 위젯 인텐트일 수도(잠금화면 "다음 단계" 탭) 있다. 둘 다 같은 설정(집중·휴식 길이,
/// 총 사이클, 타이틀·색)이 필요하므로 여기 담아 공유한다.
struct FocusAlarmPlan: Codable, Sendable {
    var focusDuration: TimeInterval
    var restDuration: TimeInterval
    var totalCycles: Int
    var sessionTitle: String
    var colorHex: String?

    private static let key = "cue.focus.alarmPlan.v1"

    func duration(for phase: FocusAlarmMetadata.Phase) -> TimeInterval {
        phase == .focus ? focusDuration : restDuration
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        SharedAppGroup.defaults.set(data, forKey: Self.key)
    }

    static func load() -> FocusAlarmPlan? {
        guard let data = SharedAppGroup.defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FocusAlarmPlan.self, from: data)
    }

    static func clear() {
        SharedAppGroup.defaults.removeObject(forKey: key)
    }
}
