//
//  FocusAlarmIntents.swift
//  cue / Shared
//
//  ⚠️ AlarmKit 도입 검증용 프로토타입.
//

import AlarmKit
import AppIntents
import Foundation

// MARK: - 타깃 멤버십
//
// 위젯이 `Button(intent:)`로 이 인텐트들을 참조하므로 **앱 + 익스텐션 양쪽**에 컴파일돼야 한다
// (pbxproj exception). 따라서 이 인텐트들은 앱 전용 타입(`FocusViewModel` 등)을 참조하면 안 된다 —
// `AlarmManager`/`FocusAlarmScheduling`만 써서 자급자족한다. perform()은 메인 앱 프로세스에서 실행되며,
// 앱이 종료돼 있어도 시스템이 백그라운드로 깨워 실행한다(체이닝이 탭에 안정적인 이유).
//
// 넷 다 `isDiscoverable = false` — 단축어 갤러리에 노출할 이유가 없다(LA 버튼·AlarmKit 전용이라
// alarmID를 손으로 채워야 해 무의미). 노출 여부는 `Button(intent:)`·`stopIntent` 경로와 무관하다.

/// 알림(경계 도달)의 secondary 버튼 — **탭 체이닝**. 다음 단계 알람을 예약한다.
struct FocusAlarmAdvanceIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Next Phase"
    static let isDiscoverable = false

    @Parameter(title: "Next Phase") var nextPhaseRaw: String
    @Parameter(title: "Cycle") var nextCycle: Int

    init() {}

    init(nextPhaseRaw: String, nextCycle: Int) {
        self.nextPhaseRaw = nextPhaseRaw
        self.nextCycle = nextCycle
    }

    func perform() async throws -> some IntentResult {
        guard let phase = FocusAlarmMetadata.Phase(rawValue: nextPhaseRaw) else { return .result() }
        // 설정·진행 상태는 App Group의 FocusAlarmPlan에서 읽는다(메인 앱이 세션 시작 시 저장).
        //
        // **자격 검사** — 이 버튼은 앱 없이도 알람을 예약하므로, 카드가 요구하는 단계가 지금
        // 허용된 단계와 일치할 때만 통과시킨다. 없으면 끝난 세션이 남긴 잠금화면 카드가 며칠 뒤
        // 스치기만 해도 새 세션이 시작된다(유령 세션). 예약에 성공하면 `schedule`이 기대값을
        // 전진시키므로 같은 카드는 두 번 먹지 않는다.
        guard let plan = FocusAlarmPlan.load(), plan.accepts(phase: phase, cycle: nextCycle) else {
            return .result()
        }
        if await FocusAlarmScheduling.schedule(phase: phase, cycle: nextCycle) != nil {
            LiveActivityAnalyticsBridge.log?("focus_phase_advanced", ["source": "live_activity"])
        }
        return .result()
    }
}

/// 카운트다운 LA의 일시정지 버튼 — 위젯이 `Button(intent:)`로 렌더, `alarmID`로 AlarmManager 제어.
struct FocusAlarmPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause"
    static let isDiscoverable = false
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        // pause 성공 시에만 로깅 — `(try?) != nil` 패턴은 CompleteReminderIntent.completeReminder 전례.
        if let id = UUID(uuidString: alarmID), (try? AlarmManager.shared.pause(id: id)) != nil {
            LiveActivityAnalyticsBridge.log?("focus_paused", ["source": "live_activity"])
        }
        return .result()
    }
}

/// 일시정지 LA의 재개 버튼.
struct FocusAlarmResumeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume"
    static let isDiscoverable = false
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID), (try? AlarmManager.shared.resume(id: id)) != nil {
            LiveActivityAnalyticsBridge.log?("focus_resumed", ["source": "live_activity"])
        }
        return .result()
    }
}

/// 정지 버튼 — 이 알람을 취소하고 **세션을 닫는다**. 다음 단계를 잇지 않는다.
///
/// plan까지 지우는 게 핵심이다. 알람만 취소하면 App Group에 plan이 남아, 잠금화면에 남은 이전
/// 경계의 카드가 계속 유효한 예약 허가증을 들고 있게 된다(유령 세션). 인앱 종료
/// (`tearDownSession`)와 대칭을 맞춘다.
struct FocusAlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End"
    static let isDiscoverable = false
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID), (try? AlarmManager.shared.cancel(id: id)) != nil {
            LiveActivityAnalyticsBridge.log?("focus_ended", ["source": "live_activity"])
        }
        FocusAlarmPlan.clear()
        return .result()
    }
}
