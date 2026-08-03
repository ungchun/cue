//
//  MemoTextMetrics.swift
//  cue / Shared
//

import CoreGraphics
import Foundation

// MARK: - 타깃 멤버십
//
// 위젯 익스텐션(메모 LA)과 앱(설정 미리보기·유닛 테스트)이 **같은 표**를 봐야 하므로 두 타깃에
// 들어간다(pbxproj exception). Domain의 `MemoTextSize`는 위젯 타깃에 없으므로 raw 문자열로 받는다
// — 위젯은 어차피 App Group UserDefaults에서 문자열로 읽는다.

/// 메모 글자 크기의 **단일 출처** — 기준 pt와 설정 배율.
///
/// **왜 한 곳인가** — 배율 표가 위젯과 미리보기에 각각 복사돼 있었다. 한쪽만 고치면 미리보기가
/// 실제 잠금화면과 다른 크기를 보여준다(미리보기의 존재 이유가 무너진다).
///
/// **왜 34인가** — 메모 탭 입력칸은 텍스트 스타일(작게 `.title2` 22 / 보통 `.title1` 28 /
/// 크게 `.largeTitle` 34)을 쓴다. LA 기준이 44였을 때 캘린더 OFF 화면만 입력보다 1.3배 커져,
/// 설정에서 고른 "보통"이 화면마다 다른 크기를 뜻했다. 기준을 `.largeTitle`에 맞춰 일치시킨다.
///
/// 완전 동일은 기본 Dynamic Type(Large) 기준이다 — 입력칸은 Dynamic Type을 따라 커지지만
/// 잠금화면 위젯은 고정 pt다. LA는 시스템이 폭·높이를 강제하므로 이 비대칭은 감수한다.
enum MemoTextMetrics {

    /// 텍스트 단독(캘린더 OFF) 기준 — 메모 탭 "크게"(`.largeTitle`)와 같은 값.
    static let textOnlyBase: CGFloat = 34

    /// 캘린더 ON 기준 — 카드를 캘린더와 반씩 나눠 쓰므로 더 작다.
    static let withCalendarBase: CGFloat = 32

    /// 다이나믹 아일랜드 확장 기준 — 알약 안이라 훨씬 작다.
    static let dynamicIslandBase: CGFloat = 24

    /// 설정 배율. 키가 없거나(첫 실행) 알 수 없는 값이면 보통으로 떨어진다.
    static func scale(_ rawTextSize: String?) -> CGFloat {
        switch rawTextSize {
        case "small": 0.7
        case "large": 1.0
        default: 0.85
        }
    }

    /// 기준 pt에 설정 배율을 적용한 실제 글자 크기.
    static func size(base: CGFloat, textSize rawTextSize: String?) -> CGFloat {
        base * scale(rawTextSize)
    }
}
