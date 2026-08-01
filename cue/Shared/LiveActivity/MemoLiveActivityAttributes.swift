//
//  MemoLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 메모 라이브 액티비티의 attributes.
///
/// 텍스트·색 모두 사용자가 활성 중에도 수정할 수 있으므로 ContentState에 둔다 — 수정 시
/// `update`로 부드럽게 반영(재시작 깜빡임 없음). `startedAt`은 게시 시점 추적용 식별 값.
///
/// 시간 흐름과 무관 — `staleDate`는 service 구현에서 nil(사용자 동작에서만 갱신).
struct MemoLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable, MonthCalendarCarrying {
        /// 카드 가운데 큰 텍스트. use case가 빈 값 검증·길이 제한을 마친 값.
        var text: String
        /// 카드 배경 색("#RRGGBB"). 파싱 실패 시 위젯이 시스템 accent로 폴백.
        var colorHex: String
        /// 카드 글자(폰트) 색("#RRGGBB"). 파싱 실패 시 위젯이 흰색으로 폴백.
        var textColorHex: String
        /// 잠금화면 월간 캘린더의 표시 월 오프셋(이번 달 = 0, ±12 클램프) — 셰브런 탭
        /// 인텐트가 갱신한다. 앱이 재게시하면 0으로 리셋(이번 달로 복귀).
        var calendarMonthOffset: Int
        /// 잠금화면 월간 캘린더(캘린더 함께 보기)의 날짜별 일정 점 — 표시 월 기준. 기본값 빈 배열.
        var monthEventDots: [LiveMonthDot]
        /// 잠금화면 월간 캘린더에서 빨갛게 칠할 공휴일(표시 월 기준 일 숫자) — 게시 시점에
        /// 앱이 사용자 캘린더에서 뽑아 싣는다. 판정 기준은 `HolidayEventPolicy`.
        var monthHolidays: [Int]
        /// 잠금화면 월간 캘린더를 그릴지 — **게시 시점에 앱이 정해 싣는다**.
        /// nil은 이 필드가 없던 옛 활성 LA뿐(위젯이 미러로 폴백). 배경은 할일 LA와 동일 —
        /// `ReminderLiveActivityAttributes.ContentState.showsCalendar` 주석 참고.
        var showsCalendar: Bool?

        init(
            text: String,
            colorHex: String,
            textColorHex: String = "#FFFFFF",
            calendarMonthOffset: Int = 0,
            monthEventDots: [LiveMonthDot] = [],
            monthHolidays: [Int] = [],
            showsCalendar: Bool? = nil
        ) {
            self.text = text
            self.colorHex = colorHex
            self.textColorHex = textColorHex
            self.calendarMonthOffset = calendarMonthOffset
            self.monthEventDots = monthEventDots
            self.monthHolidays = monthHolidays
            self.showsCalendar = showsCalendar
        }

        /// 전방 호환 디코딩 — 앱 업데이트 전 게시된 활성 LA의 옛 상태에 `textColorHex`·
        /// `calendarMonthOffset`이 없어도 재포착(sync) 시 기본값으로 채워 디코딩이 실패하지 않게 한다.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            colorHex = try container.decode(String.self, forKey: .colorHex)
            textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? "#FFFFFF"
            calendarMonthOffset = try container.decodeIfPresent(Int.self, forKey: .calendarMonthOffset) ?? 0
            monthEventDots = try container.decodeIfPresent([LiveMonthDot].self, forKey: .monthEventDots) ?? []
            monthHolidays = try container.decodeIfPresent([Int].self, forKey: .monthHolidays) ?? []
            // 옛 상태엔 없다 → nil(위젯이 미러로 폴백, 기존 동작).
            showsCalendar = try container.decodeIfPresent(Bool.self, forKey: .showsCalendar)
        }
    }

    let startedAt: Date
}
