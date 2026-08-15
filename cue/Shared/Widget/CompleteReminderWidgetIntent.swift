//
//  CompleteReminderWidgetIntent.swift
//  cue / Shared
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - 타깃 멤버십
//
// 위젯이 `Button(intent:)`로 참조하므로 **앱 + 익스텐션 양쪽**에 컴파일된다(pbxproj exception).

/// 홈 위젯 목록의 할일 원 탭 — 미리알림을 완료 처리하고 캘린더 위젯들을 갱신한다.
///
/// LA의 `CompleteReminderIntent`(`LiveActivityIntent`)를 그대로 쓰지 않는 이유:
/// 그쪽은 perform이 **메인 앱 프로세스**에서 돌아, 홈 위젯에서 탭하면 앱 콜드 런치
/// (Firebase 초기화 포함)가 통째로 끼어 완료가 수 초 늦었다. 이 인텐트는 평범한
/// `AppIntent`라 **위젯 익스텐션 프로세스 안에서** 끝난다 — 앱을 깨우지 않는다.
///
/// 대가: 익스텐션에서는 ActivityKit에 손댈 수 없어, 미리알림 LA가 떠 있으면 그 항목이
/// 앱을 열 때까지 남는다(`syncLiveActivities`가 앱 시작 시 재동기화). LA 버튼은 계속
/// `CompleteReminderIntent`를 쓴다 — 거기선 같은 프로세스라 즉시 반영이 가능해서다.
struct CompleteReminderWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete Reminder"
    /// 단축어 갤러리에 노출할 이유가 없다 — 위젯 버튼 전용.
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "reminderID") var reminderID: String

    init() {}
    init(reminderID: String) { self.reminderID = reminderID }

    func perform() async throws -> some IntentResult {
        // 완료가 성공한 경우에만 갱신 — 실패 시 화면-시스템 불일치 방지.
        guard EventKitReminderCompleter.complete(id: reminderID) else { return .result() }
        // 탭한 위젯은 인텐트 종료 후 시스템이 다시 그리지만, 같은 항목이 월 격자·시간표
        // 등 다른 캘린더 위젯에도 체크된 모습으로 보여야 하므로 함께 갱신한다.
        for kind in CalendarWidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        return .result()
    }
}
