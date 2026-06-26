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
            bigText(context.state.text, size: 56)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .activityBackgroundTint(cardColor(context.state.colorHex))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let color = cardColor(context.state.colorHex)
            return DynamicIsland {
                // 꾸욱 눌렀을 때 — 가운데에 메모 텍스트.
                DynamicIslandExpandedRegion(.center) {
                    bigText(context.state.text, size: 28)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Spacing.sm)
                }
            } compactLeading: {
                Image(systemName: "note.text")
                    .foregroundStyle(color)
            } compactTrailing: {
                // 색을 카드색으로 입힌 짧은 미리보기. 폭이 좁아 한 줄로 잘린다.
                Text(context.state.text)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(color)
                    .frame(maxWidth: 80)
            } minimal: {
                Image(systemName: "note.text")
                    .foregroundStyle(color)
            }
        }
    }

    /// 카드를 채우는 큰 텍스트 — 흰색, 가운데 정렬, 긴 문장은 축소·줄바꿈.
    private func bigText(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(4)
            .minimumScaleFactor(0.3)
    }

    /// 카드 배경 색 — 사용자 지정 hex. 비었거나 파싱 실패면 시스템 accent.
    private func cardColor(_ hex: String) -> Color {
        Color(hex: hex) ?? .accentColor
    }
}
