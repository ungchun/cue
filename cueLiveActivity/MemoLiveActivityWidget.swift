//
//  MemoLiveActivityWidget.swift
//  cueLiveActivity
//

import ActivityKit
import SwiftUI
import WidgetKit

/// 메모 라이브 액티비티 위젯.
///
/// 잠금화면: 사용자 색으로 채운 카드 가운데에 메모 한 문장을 **큰 텍스트**로. 긴 문장은
/// `minimumScaleFactor`로 줄여 카드 안에 담는다(스크린샷의 "엄청 큰 텍스트" 형태).
/// Dynamic Island: expanded 가운데에 메모 텍스트, compact/minimal엔 메모 아이콘(+짧은 미리보기).
///
/// 큰 헤드라인은 카드 폭을 꽉 채우는 게 목적이라 고정 크기(`.system(size:)`)를 쓴다 —
/// FocusAlarm 위젯의 카운트다운과 같은, LA 한정 예외. 디자인 색 규칙대로 카드색은 외부 데이터
/// (`Color(hex:)`)로만 받고, 그 외 색은 시스템 컬러를 따른다.
struct MemoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MemoLiveActivityAttributes.self) { context in
            // 잠금화면 — 카드 배경을 사용자 색으로 칠하고 가운데 큰 흰 텍스트.
            bigText(context.state.text, size: 44)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .activityBackgroundTint(cardColor(context.state.colorHex))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 꾸욱 눌렀을 때 — 메모 텍스트를 expanded 영역 한가운데에. maxWidth·maxHeight
                // 모두 무한으로 채우고 center 정렬해 좌우·상하 정중앙에 오게 한다.
                DynamicIslandExpandedRegion(.center) {
                    bigText(context.state.text, size: 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.horizontal, Spacing.sm)
                }
            } compactLeading: {
                // 일정·할일과 동일 — 동그라미 점.
                Image(systemName: "circle.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                // 일정·할일과 동일 — 오늘(자정까지) 잔여를 나타내는 원형 링.
                DayProgressRing()
            } minimal: {
                Image(systemName: "circle.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    /// 카드를 채우는 큰 텍스트 — 흰색, 긴 문장은 축소·줄바꿈.
    /// 줄 정렬은 `.leading`(왼쪽부터) — 여러 줄일 때 들쭉날쭉하지 않고 단락처럼 채워진다.
    /// 블록 자체는 호출처 frame이 가운데 두므로, 한두 줄 짧은 메모는 가운데로 보인다.
    private func bigText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .lineLimit(4)
            // 1줄 짧은 메모는 기본 크기 그대로, 여러 줄로 길어져도 0.5배까지만 줄어 너무
            // 작아지지 않게 — "1줄은 크고 멀티라인은 작은" 편차를 줄인다.
            .minimumScaleFactor(0.5)
    }

    /// 카드 배경 색 — 사용자 지정 hex. 비었거나 파싱 실패면 시스템 accent.
    private func cardColor(_ hex: String) -> Color {
        Color(hex: hex) ?? .accentColor
    }
}
