//
//  AllDayStripLimits.swift
//  cue / Shared
//

import CoreGraphics

/// 시간표 위젯의 종일 줄에서 **몇 개를 제목으로, 몇 개를 막대로** 그릴지.
///
/// 뷰가 아니라 여기 두는 이유는 이 값들이 **열 폭에서 역산한 계산**이기 때문이다.
/// 폭이 바뀌면 같이 움직여야 하고, 그 관계가 맞는지는 화면 없이 검증할 수 있어야 한다.
enum AllDayStripLimits {

    /// 제목이 제목 구실을 하려면 칩이 최소 이만큼은 돼야 한다.
    ///
    /// **네 글자 기준**이다. 렌더해서 재보니 "건강검진"이 34pt고 좌우 여백이 6pt쯤 —
    /// 이보다 좁으면 두세 글자에서 잘려 무슨 일정인지 알 수 없다. 그럴 바엔 막대로
    /// 그리는 편이 개수라도 정확히 알려준다.
    ///
    /// 이 값이 3일 위젯(열 100pt)을 2개로, 1일 위젯(300pt)을 3개로 가른다.
    static let minimumTitledChipWidth: CGFloat = 42

    /// 제목 없이 색만 남기는 막대의 폭.
    static let barWidth: CGFloat = 4

    /// 막대로 그릴 최대 개수.
    ///
    /// 막대는 고정 폭이라 개수만큼 선형으로 늘어난다. 좁은 열에서 스무 개가 붙으면
    /// 제목 칩을 밀어내는데, 그 지경이면 세어지지도 않아 더 그릴 값이 없다.
    static let barLimit = 6

    /// 그 열 폭에서 **제목을 붙여 그릴 수 있는 개수**.
    ///
    /// 칩 사이 틈(1pt)까지 넣고 나눈다. 3일 위젯(100pt)은 2개, 1일 위젯(300pt)은
    /// 3개가 나오는데, 후자는 계산상 더 들어가도 상한을 둔다 — 종일이 많은 날에
    /// 줄 전체가 제목으로 꽉 차면 정작 아래 시간표가 눈에 안 들어온다.
    static func titledCount(columnWidth: CGFloat) -> Int {
        let fits = Int((columnWidth + 1) / (minimumTitledChipWidth + 1))
        return max(1, min(3, fits))
    }
}
