//
//  FocusCountdownFormatTests.swift
//  cueTests
//
//  집중 LA 카운트다운의 표시 문자열과 폭 예약 템플릿.
//

import Foundation
import Testing
@testable import cue

/// 잠금화면 집중 LA에서 단계 라벨과 숫자 사이 간격을 결정하는 규칙.
///
/// 증상(2026-08-02 보고): "집중 24:57"은 라벨이 숫자에 붙는데 "휴식  4:50"은 한 칸 떨어진다.
///
/// 원인 — `Text(timerInterval:)`은 시:분:초 기준으로 폭을 넓게 예약해버려서, 위젯은 숨긴
/// `"00:00"` 텍스트로 프레임을 5자에 고정하고 그 위에 우측정렬 overlay로 숫자를 얹는다.
/// 5자짜리(`24:57`)는 템플릿에 꽉 차 라벨과 붙지만, 4자짜리(`4:50`)는 오른쪽 끝에 정렬되면서
/// **한 자리 폭이 라벨 쪽에 빈칸으로 남는다.**
///
/// 규칙 — 템플릿을 "항상 5자"가 아니라 **지금 표시되는 자릿수**에 맞춘다. 시스템 타이머가
/// 그리는 모양(앞자리 0 없음, 1시간 이상은 h:mm:ss)을 그대로 재현한 뒤 숫자만 자리표시자로
/// 바꾸면 길이가 정확히 일치한다.
struct FocusCountdownFormatTests {

    // MARK: - 표시 문자열 — 시스템 타이머와 같은 모양

    /// 10분 미만은 분에 앞자리 0을 붙이지 않는다 — 이게 4자가 되는 경우다.
    @Test func formatsUnderTenMinutesWithoutLeadingZero() {
        #expect(FocusCountdownFormat.text(4 * 60 + 50) == "4:50")
        #expect(FocusCountdownFormat.text(9) == "0:09")
        #expect(FocusCountdownFormat.text(0) == "0:00")
    }

    /// 10분 이상 1시간 미만은 mm:ss 5자.
    @Test func formatsMinutesAndSeconds() {
        #expect(FocusCountdownFormat.text(24 * 60 + 57) == "24:57")
        #expect(FocusCountdownFormat.text(10 * 60) == "10:00")
    }

    /// 1시간 이상은 h:mm:ss — 긴 집중 세션에서 분만 쓰면 90:00 같은 시스템과 다른 표기가 된다.
    @Test func formatsHoursWhenOverAnHour() {
        #expect(FocusCountdownFormat.text(90 * 60) == "1:30:00")
        #expect(FocusCountdownFormat.text(3600) == "1:00:00")
    }

    /// 음수(발화 직후 등)는 0으로 클램프 — "-1:00" 같은 표시를 만들지 않는다.
    @Test func clampsNegativeToZero() {
        #expect(FocusCountdownFormat.text(-30) == "0:00")
    }

    // MARK: - 폭 템플릿 — 표시 문자열과 길이가 같아야 한다

    /// **재현 핵심.** 4:50짜리 휴식은 5자가 아니라 4자를 예약해야 라벨이 숫자에 붙는다.
    @Test func templateMatchesShortCountdownWidth() {
        #expect(FocusCountdownFormat.widthTemplate(4 * 60 + 50) == "0:00")
    }

    /// 5자짜리는 지금과 동일 — 집중 24:57이 지금 정상인 건 우연히 템플릿과 길이가 같아서다.
    @Test func templateMatchesFiveCharacterCountdown() {
        #expect(FocusCountdownFormat.widthTemplate(24 * 60 + 57) == "00:00")
    }

    /// 시간 단위가 붙으면 템플릿도 함께 길어진다 — 짧게 잡으면 숫자가 잘린다.
    @Test func templateGrowsForHours() {
        #expect(FocusCountdownFormat.widthTemplate(90 * 60) == "0:00:00")
    }

    /// 어떤 값이든 템플릿 길이 == 표시 문자열 길이. 이게 어긋나면 빈칸이 생기거나 잘린다.
    @Test func templateLengthAlwaysMatchesTextLength() {
        for seconds in [0, 1, 59, 60, 599, 600, 3599, 3600, 7200, 86_399] {
            let value = TimeInterval(seconds)
            #expect(
                FocusCountdownFormat.widthTemplate(value).count == FocusCountdownFormat.text(value).count,
                "\(seconds)초에서 템플릿과 표시 길이가 어긋난다"
            )
        }
    }
}
