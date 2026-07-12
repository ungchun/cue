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

/// 알림(경계 도달)의 secondary 버튼 — **탭 체이닝**. 다음 단계 알람을 예약한다.
struct FocusAlarmAdvanceIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Next Phase"

    @Parameter(title: "Next Phase") var nextPhaseRaw: String
    @Parameter(title: "Cycle") var nextCycle: Int

    init() {}

    init(nextPhaseRaw: String, nextCycle: Int) {
        self.nextPhaseRaw = nextPhaseRaw
        self.nextCycle = nextCycle
    }

    func perform() async throws -> some IntentResult {
        guard let phase = FocusAlarmMetadata.Phase(rawValue: nextPhaseRaw) else { return .result() }
        // 설정은 App Group의 FocusAlarmPlan에서 읽는다(메인 앱이 세션 시작 시 저장).
        _ = await FocusAlarmScheduling.schedule(phase: phase, cycle: nextCycle)
        return .result()
    }
}

/// 카운트다운 LA의 일시정지 버튼 — 위젯이 `Button(intent:)`로 렌더, `alarmID`로 AlarmManager 제어.
struct FocusAlarmPauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause"
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.pause(id: id) }
        return .result()
    }
}

/// 일시정지 LA의 재개 버튼.
struct FocusAlarmResumeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Resume"
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.resume(id: id) }
        return .result()
    }
}

/// 정지 버튼 — 이 알람을 취소한다(세션 종료). 다음 단계를 잇지 않는다.
struct FocusAlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "End"
    @Parameter(title: "alarmID") var alarmID: String
    init() {}
    init(alarmID: String) { self.alarmID = alarmID }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) { try? AlarmManager.shared.cancel(id: id) }
        return .result()
    }
}
