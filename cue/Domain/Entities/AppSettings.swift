//
//  AppSettings.swift
//  cue / Domain
//

import Foundation

/// 앱 화면 밝기 테마. 시스템 설정을 따르거나(.system) 라이트·다크로 고정.
enum AppColorScheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

/// 메모 텍스트 크기 — 입력 화면과 라이브 액티비티 카드에 공통 적용. 기본은 현재 동작인 `.large`.
enum MemoTextSize: String, Codable, Sendable, CaseIterable {
    case small
    case medium
    case large
}

/// Dynamic Island 진행 링이 무엇을 기준으로 줄어들지.
/// `.day24`는 오늘 자정까지(현재 동작), `.activity8h`는 LA가 게시된 뒤 ~8시간 수명을 센다.
enum ProgressRingBasis: String, Codable, Sendable, CaseIterable {
    case day24
    case activity8h
}

/// 앱 전역 설정. 단일 인스턴스로 UserDefaults에 JSON 저장된다(스코프 없음 —
/// 섹션·리스트별로 나뉘는 `ReminderSortSettings`와 달리 앱에 하나뿐).
///
/// 필드는 기능이 추가될 때마다 늘어난다. 그래서 `init(from:)`을 직접 구현해
/// **저장 당시 없던 새 필드를 기본값으로 채운다**(전방 호환) — 설정 하나를 더해도
/// 기존 사용자의 저장본이 통째로 버려지지 않게 하기 위함.
struct AppSettings: Codable, Equatable, Sendable {
    /// 앱 전체 밝기 테마.
    var colorScheme: AppColorScheme
    /// 앱을 켤 때 처음 보여줄 탭의 식별자(`AppTab.rawValue`). 기본은 할일.
    /// Domain은 `AppTab`(Presentation·SwiftUI)을 모르므로 문자열로만 보관한다.
    var startTabID: String
    /// 집중 단계 종료 시 실제 알림 소리를 낼지. `false`면 무음(현재 기본 동작).
    var focusEndSound: Bool
    /// 집중 단계 전환 시 인앱 햅틱(진동)을 줄지. 기본 켜짐.
    var focusHaptic: Bool
    /// 포그라운드에서 한 단계가 끝나면 알림 없이 자동으로 다음 단계로 넘어갈지. 기본 꺼짐
    /// (현재 동작 — 종료 알림을 띄우고 사용자가 탭). 잠금/백그라운드는 항상 알림 탭이 필요하다.
    var focusAutoAdvance: Bool
    /// 메모 텍스트 크기. 기본 `.large`(현재 largeTitle 동작 유지).
    var memoTextSize: MemoTextSize
    /// Dynamic Island 진행 링 기준. 기본 `.day24`(현재 동작).
    var progressRingBasis: ProgressRingBasis

    static let `default` = AppSettings(
        colorScheme: .system,
        startTabID: "reminder",
        focusEndSound: false,
        focusHaptic: true,
        focusAutoAdvance: false,
        memoTextSize: .large,
        progressRingBasis: .day24
    )
}

extension AppSettings {
    /// 전방 호환 디코딩 — 저장 당시 없던 키는 `.default`의 값으로 채운다.
    /// (필드를 추가해도 옛 JSON이 디코딩 실패로 통째로 날아가지 않도록.)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppSettings.default
        colorScheme = try container.decodeIfPresent(AppColorScheme.self, forKey: .colorScheme)
            ?? fallback.colorScheme
        startTabID = try container.decodeIfPresent(String.self, forKey: .startTabID)
            ?? fallback.startTabID
        focusEndSound = try container.decodeIfPresent(Bool.self, forKey: .focusEndSound)
            ?? fallback.focusEndSound
        focusHaptic = try container.decodeIfPresent(Bool.self, forKey: .focusHaptic)
            ?? fallback.focusHaptic
        focusAutoAdvance = try container.decodeIfPresent(Bool.self, forKey: .focusAutoAdvance)
            ?? fallback.focusAutoAdvance
        memoTextSize = try container.decodeIfPresent(MemoTextSize.self, forKey: .memoTextSize)
            ?? fallback.memoTextSize
        progressRingBasis = try container.decodeIfPresent(ProgressRingBasis.self, forKey: .progressRingBasis)
            ?? fallback.progressRingBasis
    }
}
