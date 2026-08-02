//
//  FocusCountdownFormat.swift
//  cue / Shared
//

import Foundation

// MARK: - 타깃 멤버십
//
// 위젯 익스텐션(집중 LA 렌더)이 쓰고, 유닛 테스트가 규칙을 검증하려면 앱 타깃에도 있어야 한다
// — 양쪽에 들어간다(pbxproj exception). Foundation만 참조하는 순수 규칙이라 어느 타깃에서도 안전하다.

/// 집중 LA 카운트다운의 표시 문자열과 **폭 예약 템플릿**.
///
/// **왜 템플릿이 필요한가** — `Text(timerInterval:)`은 시:분:초 기준으로 폭을 넓게 예약한다.
/// 그대로 두면 mm:ss만 보일 때 라벨과 숫자 사이가 벌어지므로, 위젯은 같은 폰트의 숨긴 텍스트로
/// 프레임을 잡고 그 위에 우측정렬 overlay로 타이머를 얹는다. 그 숨긴 텍스트가 여기서 나온다.
///
/// **왜 고정 "00:00"이면 안 되는가** — 5자로 고정하면 `4:50`처럼 4자인 값이 오른쪽 끝에 정렬되며
/// 한 자리 폭이 라벨 쪽 빈칸으로 남는다("집중 24:57"은 붙는데 "휴식  4:50"은 떨어지던 원인).
/// 표시 문자열과 **길이가 같은** 템플릿을 써야 라벨이 숫자에 밀착한다.
enum FocusCountdownFormat {

    /// 시스템 타이머와 같은 모양 — 앞자리 0을 붙이지 않고, 1시간 이상이면 h:mm:ss.
    static func text(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// 폭 예약용 자리표시자 — 표시 문자열의 숫자만 `0`으로 바꾼 것이라 길이가 항상 일치한다.
    static func widthTemplate(_ seconds: TimeInterval) -> String {
        String(text(seconds).map { $0.isNumber ? "0" : $0 })
    }
}
