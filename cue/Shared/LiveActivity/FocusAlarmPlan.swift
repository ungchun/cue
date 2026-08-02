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
/// 단계별 알람을 하나씩 예약·체이닝하는데, 다음 단계를 예약하는 주체가 메인 앱일 수도(인앱 스킵)
/// 위젯 인텐트일 수도(잠금화면 "다음 단계" 탭) 있다. 둘 다 같은 설정(집중·휴식 길이,
/// 총 사이클, 타이틀·색)이 필요하므로 여기 담아 공유한다.
///
/// **진행 상태(`nextAllowed`)를 함께 드는 이유** — 잠금화면 카드의 버튼은 앱 없이도 알람을
/// 예약한다. 설정만 담던 시절엔 "plan이 존재하는가"가 유일한 관문이었는데, 그 plan은 인앱
/// 종료 말고는 지워지지 않아(잠금화면 종료·알림 방치·강제종료가 전부 남긴다) **끝난 세션의
/// 카드가 며칠 뒤에도 유효**했다. 한 번 스치면 새 단계가 시작되는 유령 세션의 원인이다.
/// 이제 카드가 요구하는 단계와 여기 적힌 기대값이 일치할 때만 예약을 허용하고, 예약에 성공하면
/// 기대값이 전진하므로 유효한 카드도 **한 번만** 먹는다.
struct FocusAlarmPlan: Codable, Sendable {

    /// 세션의 한 단계 — 잠금화면 카드가 요구하는 단계와 대조할 좌표.
    struct Step: Codable, Sendable, Equatable {
        let phase: FocusAlarmMetadata.Phase
        let cycle: Int
    }

    var focusDuration: TimeInterval
    var restDuration: TimeInterval
    var totalCycles: Int
    var sessionTitle: String
    var colorHex: String?
    /// 단계 종료 알림에 실제 소리를 낼지(설정 "집중 종료 소리"). 세션 시작 시 스냅샷으로 굳혀,
    /// 메인 앱·위젯 인텐트가 같은 소리 정책으로 단계를 예약한다. 기본 무음(false).
    var soundEnabled: Bool = false

    /// 다음에 **예약이 허용되는** 단계. nil이면 이어질 단계가 없다(세션 완주) — 어떤 카드도 안 먹는다.
    var nextAllowed: Step?
    /// 지금 걸려 있는 알람 — `AlarmManager.alarms` 조회가 실패해도 이 id로 취소할 수 있게 남긴다.
    var currentAlarmID: UUID?

    // v1은 진행 상태가 없어 자격 판정을 할 수 없다. 키를 올려 **기기에 남아 있던 옛 plan을
    // 무효화**한다 — 기본값으로 디코딩해 살려두면 지금 떠 있는 유령 카드가 그대로 유효해진다.
    private static let key = "cue.focus.alarmPlan.v2"

    func duration(for phase: FocusAlarmMetadata.Phase) -> TimeInterval {
        phase == .focus ? focusDuration : restDuration
    }

    /// 이 단계를 지금 예약해도 되는가 — 잠금화면 체이닝 인텐트 전용 관문.
    ///
    /// 인앱 경로(Start·Skip)는 이 판정을 쓰지 않는다. 잠금화면에서 한 단계 넘어간 뒤 앱이 아직
    /// 채택하지 못한 상태의 Skip이 조용히 무시되기 때문이고, 그쪽은 앱이 살아 있고 사용자가
    /// 화면을 보며 누르는 상황이라 VM이 권위다.
    func accepts(phase: FocusAlarmMetadata.Phase, cycle: Int) -> Bool {
        nextAllowed == Step(phase: phase, cycle: cycle)
    }

    /// 기대값·현재 알람을 갈아끼운 사본 — 설정 스냅샷(길이·타이틀·색·소리)은 세션 내내 고정이다.
    func expecting(_ step: Step?, currentAlarmID: UUID? = nil) -> FocusAlarmPlan {
        var copy = self
        copy.nextAllowed = step
        copy.currentAlarmID = currentAlarmID
        return copy
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
