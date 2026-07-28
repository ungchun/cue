//
//  ShiftWidgetRangeIntent.swift
//  cue / Shared
//

import AppIntents
import Foundation
import WidgetKit

// MARK: - 타깃 멤버십
//
// 위젯이 `Button(intent:)`로 참조하므로 **앱 + 익스텐션 양쪽**에 컴파일된다(pbxproj exception).
// 앱 전용 타입은 참조하지 않고 시스템 프레임워크와 공유 타입만으로 자급자족한다.
//
// LA의 `ShiftCalendarMonthIntent`와 달리 평범한 `AppIntent`다 — 홈 화면 위젯의 버튼은
// **위젯 익스텐션 프로세스**에서 실행되고, 끝나면 WidgetKit이 타임라인을 다시 요청한다.
// 앱을 띄우지 않아야 하므로 `openAppWhenRun`은 false.

/// 위젯의 ‹ › 셰브런 탭 — 표시 구간(월/일)을 앞뒤로 민다.
///
/// 실제 이동량은 `WidgetRangeOffsetStore`가 클램프하고, 날이 바뀌면 알아서 오늘로 되돌린다.
struct ShiftWidgetRangeIntent: AppIntent {
    static let title: LocalizedStringResource = "Shift Widget Range"
    /// 단축어 갤러리에 노출할 이유가 없다 — 위젯 내부 조작 전용.
    static let isDiscoverable = false
    static let openAppWhenRun = false

    /// 어느 위젯의 구간인지 — `WidgetRangeKind.rawValue`.
    @Parameter(title: "kind") var kindRaw: String
    /// 이동 방향·양. 월 위젯은 개월, 1일·3일 위젯은 일 단위다.
    @Parameter(title: "delta") var delta: Int

    init() {}

    init(kind: WidgetRangeKind, delta: Int) {
        self.kindRaw = kind.rawValue
        self.delta = delta
    }

    func perform() async throws -> some IntentResult {
        guard let kind = WidgetRangeKind(rawValue: kindRaw) else { return .result() }
        WidgetRangeOffsetStore.shared.shift(by: delta, for: kind)
        // WidgetKit이 인텐트 종료 후 자동으로 다시 그리지만, 대상 위젯만 콕 집어 갱신해
        // 다른 위젯의 불필요한 타임라인 재생성을 피한다.
        WidgetCenter.shared.reloadTimelines(ofKind: kind.widgetKind)
        return .result()
    }
}

extension WidgetRangeKind {
    /// WidgetKit에 등록된 위젯 `kind` 문자열 — 셰브런이 자기 위젯만 갱신하는 데 쓴다.
    var widgetKind: String {
        switch self {
        case .month: return "azhy.cue.widget.month"
        case .threeDay: return "azhy.cue.widget.threeDay"
        case .oneDay: return "azhy.cue.widget.oneDay"
        }
    }
}
