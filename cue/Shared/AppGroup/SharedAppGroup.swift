//
//  SharedAppGroup.swift
//  cue / Shared
//

import Foundation

/// 메인 앱과 widget extension(App Intent) 사이의 공유 통로.
///
/// 두 target 모두 Xcode의 Signing & Capabilities에서 동일 App Group ID로 entitlement이
/// 추가돼 있어야 한다 — 추가되지 않으면 `UserDefaults(suiteName:)`이 nil을 반환하고
/// `.standard`로 폴백(이때 process 간 공유는 깨진다 — 디버그 시 entitlement부터 확인).
///
/// 현재는 집중 세션 설정 스냅샷(`FocusAlarmPlan`)이 사용한다 — 메인 앱이 저장하고 위젯 익스텐션의
/// AlarmKit 체이닝 인텐트가 읽는다. 향후 다른 공유 상태도 같은 suite를 통한다.
enum SharedAppGroup {
    /// Group ID. Xcode entitlement(`com.apple.security.application-groups`)에 같은 값을
    /// 두 target 모두에 등록해야 process 간 공유가 작동한다.
    static let identifier = "group.azhy.cue"

    /// 두 process가 공유하는 UserDefaults. entitlement 누락 시 `.standard`로 폴백 —
    /// 단일 process 내 동작은 유지되지만 공유는 끊긴다.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }

    /// 위젯(다른 프로세스)이 읽는 LA 설정/상태 미러 키. 위젯은 Domain 타입을 모르므로
    /// rawValue 문자열·타임스탬프만 공유한다 — 메인 앱이 설정 저장·LA 게시 시 갱신.
    enum Keys {
        /// 메모 LA 카드 글자 크기(`MemoTextSize.rawValue`).
        static let memoTextSize = "cue.la.memoTextSize.v1"
        /// 메모 LA에 월간 캘린더를 함께 표시할지(`Bool`).
        static let memoShowsCalendar = "cue.la.memoShowsCalendar.v1"
        /// 일정 LA에 월간 캘린더를 함께 표시할지(`Bool`).
        static let scheduleShowsCalendar = "cue.la.scheduleShowsCalendar.v1"
        /// 할일 LA에 월간 캘린더를 함께 표시할지(`Bool`).
        static let reminderShowsCalendar = "cue.la.reminderShowsCalendar.v1"
        /// 숨긴 캘린더 id 목록(`[String]`) — LA 월간 캘린더 점이 숨긴 캘린더 이벤트를 거를 때 읽는다.
        static let hiddenCalendarIDs = "cue.la.hiddenCalendarIDs.v1"
        /// 숨긴 할일 목록 id(`[String]`) — 홈 위젯이 미리알림을 거를 때 읽는다.
        ///
        /// 캘린더와 **별도 키**여야 한다: 미리알림 목록도 `EKCalendar`지만 식별자 공간이 달라,
        /// 캘린더 목록으로 대조하면 영원히 일치하지 않아 필터가 통째로 무력화된다.
        static let hiddenReminderListIDs = "cue.la.hiddenReminderListIDs.v1"
        /// 가장 최근 LA 게시 시각(`timeIntervalSince1970`) — 진행 링의 8시간 기준점.
        static let ringAnchor = "cue.la.ringAnchor.v1"
        /// 프리미엄 구독 여부(`Bool`) — 위젯이 잠금 화면을 띄울지 가른다.
        ///
        /// 위젯 익스텐션에서 StoreKit을 직접 조회하지 않는 이유: 타임라인을 만들 때마다
        /// 네트워크를 타는 비용이 들고, 실패하면 유료 사용자에게 잠금이 뜬다.
        /// 앱이 구독 상태를 확인할 때마다 여기 미러링하고 위젯은 읽기만 한다.
        static let isPremium = "cue.premium.isActive.v1"
    }

    /// 프리미엄 구독 여부 — 앱이 쓰고 위젯이 읽는다.
    ///
    /// 기본값 `false`. 앱을 한 번도 안 열었거나 entitlement가 빠져 공유가 끊기면
    /// 잠금 화면이 뜬다 — 유료 기능이 새는 것보다 낫다.
    static var isPremium: Bool {
        get { defaults.bool(forKey: Keys.isPremium) }
        set { defaults.set(newValue, forKey: Keys.isPremium) }
    }
}
