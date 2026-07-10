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
            // 잠금화면 — 카드 배경을 사용자 색으로 칠하고 가운데 큰 텍스트(사용자 글자색).
            // 설정 "메모 + 캘린더"(App Group 미러)면 왼쪽 반을 월간 캘린더로 분할.
            // 캘린더 모드는 패딩을 줄여 캘린더가 최대 크기로 그려지게 한다.
            lockScreen(context.state)
                .padding(.horizontal, showsCalendar() ? Spacing.md : Spacing.lg)
                .padding(.vertical, showsCalendar() ? Spacing.sm : Spacing.md)
                .activityBackgroundTint(cardColor(context.state.colorHex))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // 좌상단 — 앱 정체성 라벨 "Cue"(락스크린 헤더와 같은 자리·역할).
                DynamicIslandExpandedRegion(.leading) {
                    Text("Cue")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, Spacing.sm)
                }
                // 우상단 — 오늘(자정까지) "N시간 남음".
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(hoursLeftToday())시간 남음")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Spacing.sm)
                }
                // 메모 텍스트 — Reminder 위젯처럼 bottom 리전(full폭, 위 코너 아래)에 둔다.
                // center에 큰 텍스트를 두면 위 코너(leading/trailing)와 겹쳐 가려진다.
                DynamicIslandExpandedRegion(.bottom) {
                    bigText(context.state.text, size: 24 * memoSizeScale(), color: textColor(context.state.textColorHex))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, Spacing.sm)
                }
            } compactLeading: {
                // 일정·할일과 동일 — 앱 아이콘 마크.
                AppIconMarkView()
            } compactTrailing: {
                // 일정·할일과 동일 — 오늘(자정까지) 잔여를 나타내는 원형 링.
                DayProgressRing()
            } minimal: {
                AppIconMarkView()
            }
        }
    }

    /// 잠금화면 본문 — 캘린더 설정에 따라 텍스트 단독 또는 좌(캘린더)/우(텍스트) 분할.
    /// 캘린더 색은 카드가 사용자 배경색이라 시스템 컬러 대신 사용자 글자색 계열을 주입한다.
    @ViewBuilder
    private func lockScreen(_ state: MemoLiveActivityAttributes.ContentState) -> some View {
        let color = textColor(state.textColorHex)
        if showsCalendar() {
            HStack(alignment: .center, spacing: Spacing.md) {
                MonthCalendarView(
                    grid: MonthCalendarGrid(now: .now, monthOffset: state.calendarMonthOffset),
                    intentTarget: ShiftCalendarMonthIntent.memoTarget,
                    foreground: color,
                    secondaryForeground: color.opacity(0.55)
                )
                .frame(maxWidth: .infinity)
                // 반쪽에선 44가 과해 한 단계 줄인다(설정 배율은 그대로 곱해짐).
                bigText(state.text, size: 32 * memoSizeScale(), color: color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            bigText(state.text, size: 44 * memoSizeScale(), color: color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 설정 미러 — 위젯은 렌더 시점에 읽는다(상태 갱신 시 재렌더).
    private func showsCalendar() -> Bool {
        SharedAppGroup.defaults.bool(forKey: SharedAppGroup.Keys.memoShowsCalendar)
    }

    /// 카드를 채우는 큰 텍스트 — 흰색, 긴 문장은 축소·줄바꿈.
    /// 줄 정렬은 `.leading`(왼쪽부터) — 여러 줄일 때 들쭉날쭉하지 않고 단락처럼 채워진다.
    /// 블록 자체는 호출처 frame이 가운데 두므로, 한두 줄 짧은 메모는 가운데로 보인다.
    private func bigText(_ text: String, size: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
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

    /// 카드 글자 색 — 사용자 지정 hex. 비었거나 파싱 실패면 흰색(기존 동작).
    private func textColor(_ hex: String) -> Color {
        Color(hex: hex) ?? .white
    }

    /// 남은 시간(시 단위, 올림) — DayProgressRing과 같은 기준(자정 또는 LA 8시간 수명)을 따른다.
    /// 렌더 시점 값이라 LA 콘텐츠 갱신 때 갱신된다(링은 timerInterval로 별도 자동 갱신).
    private func hoursLeftToday(_ now: Date = .now) -> Int {
        let range = DayProgressRing.range(now: now)
        return max(0, Int(ceil(range.upperBound.timeIntervalSince(now) / 3600)))
    }

    /// 메모 글자 크기 배율 — 설정(App Group 미러 "small"/"medium"/"large")을 읽어 큰 텍스트를 줄인다.
    /// 키가 없으면(첫 실행·미저장) 기본 `.large` = 1.0으로 현재 크기를 유지한다.
    private func memoSizeScale() -> CGFloat {
        switch SharedAppGroup.defaults.string(forKey: SharedAppGroup.Keys.memoTextSize) {
        case "small": 0.7
        case "medium": 0.85
        default: 1.0
        }
    }
}
