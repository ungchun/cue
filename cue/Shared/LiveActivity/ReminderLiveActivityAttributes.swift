//
//  ReminderLiveActivityAttributes.swift
//  cue / Shared
//

import ActivityKit
import Foundation

/// 미리알림 라이브 액티비티의 attributes.
///
/// `listTitle`(예: "오늘", "장보기")은 시작 시 결정되고 활성 중엔 변하지 않으므로 attributes에.
/// 표시 항목·남은 개수는 사용자 동작(완료 토글·항목 추가/삭제)에 따라 갱신되므로 ContentState.
///
/// 시간 흐름과 무관 — `staleDate`는 service 구현에서 nil 또는 매우 멀리 둔다.
struct ReminderLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable, MonthCalendarCarrying {
        var items: [LiveReminderItem]
        var remaining: Int
        /// 오늘 처리할 할일 수(오늘 마감 + 마감 미지정, 지난·완료 제외) — Dynamic Island 주간
        /// 캘린더 스트립 우상단 카운트용. 앱에서 도메인 데이터로 계산해 싣는다(위젯엔 날짜·완료
        /// 정보가 없어 직접 못 셈). 기본값 0 — 기존 ContentState 생성부 호환.
        var todayCount: Int = 0
        /// Dynamic Island 주간 스트립의 날짜별 일정 점(오늘 제외) — 각 날 캘린더 이벤트 색.
        /// 할일 LA도 일정 LA와 동일한 스트립을 그리므로 캘린더 이벤트 점을 함께 싣는다.
        /// 기본값 빈 배열 — 기존 ContentState 생성부/전방 디코딩 호환.
        var weekEventDots: [LiveDayEventDots] = []
        /// 잠금화면 월간 캘린더의 표시 월 오프셋(이번 달 = 0, ±12 클램프) — 셰브런 탭 인텐트가 갱신.
        /// 앱이 재게시하면 0으로 리셋. 일정 LA와 동일. 기본값 0 — 전방 디코딩 호환.
        var calendarMonthOffset: Int = 0
        /// 잠금화면 월간 캘린더(캘린더 함께 보기)의 날짜별 일정 점 — 표시 월 기준. 기본값 빈 배열.
        var monthEventDots: [LiveMonthDot] = []
        /// 잠금화면 월간 캘린더에서 빨갛게 칠할 공휴일(표시 월 기준 일 숫자).
        ///
        /// **게시 시점에 앱이 사용자 캘린더에서 뽑아 싣는다** — 위젯은 렌더 시점에 EventKit을
        /// 읽을 수 없다. 판정 기준은 `HolidayEventPolicy`. 기본값 빈 배열 — 전방 디코딩 호환.
        var monthHolidays: [Int] = []
        /// 잠금화면 월간 캘린더를 그릴지 — **게시 시점에 앱이 정해 싣는다**.
        ///
        /// 위젯이 렌더 시점에 App Group 미러를 직접 읽던 방식은, 미러가 저장값과 어긋나면
        /// "설정은 ON인데 캘린더가 안 뜬다"가 되고 위젯 프로세스에선 검증도 복구도 불가능했다.
        /// 결정을 상태에 실으면 표시가 게시 시점의 진실로 고정된다.
        /// nil은 이 필드가 없던 **옛 활성 LA**뿐 — 그때만 위젯이 미러로 폴백한다(기존 동작).
        var showsCalendar: Bool? = nil
        /// 온보딩 목업 게시 마커 — 예시만 골라 정리(`endSamples`)하고 월 이동 셰브런을 숨긴다.
        /// 표시 결정과 **분리한다**: 예전엔 옵셔널 하나(`showsCalendarOverride`)가 "표시 강제"와
        /// "예시 마커"를 겸해, 실사용 게시에 표시값을 실으면 실사용이 예시로 오인돼 정리됐다.
        var isSample: Bool = false
    }

    let listTitle: String
}

extension ReminderLiveActivityAttributes.ContentState {
    /// 전방 호환 디코딩 — 옛 활성 LA에 `weekEventDots`가 없어도 기본값으로 채워 디코딩 실패를 막는다.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([LiveReminderItem].self, forKey: .items)
        remaining = try container.decode(Int.self, forKey: .remaining)
        todayCount = try container.decodeIfPresent(Int.self, forKey: .todayCount) ?? 0
        weekEventDots = try container.decodeIfPresent([LiveDayEventDots].self, forKey: .weekEventDots) ?? []
        calendarMonthOffset = try container.decodeIfPresent(Int.self, forKey: .calendarMonthOffset) ?? 0
        monthEventDots = try container.decodeIfPresent([LiveMonthDot].self, forKey: .monthEventDots) ?? []
        monthHolidays = try container.decodeIfPresent([Int].self, forKey: .monthHolidays) ?? []
        // 옛 상태엔 두 키가 없다 → nil(미러 폴백) · false(실사용). 옛 `showsCalendarOverride`는
        // 읽지 않는다 — 그 키가 박힌 건 온보딩 목업뿐이고, 목업은 첫 실행 세션에서만 살아
        // 앱 업데이트를 넘어 재포착될 창이 사실상 없다(시스템이 8시간 뒤 자동 종료).
        showsCalendar = try container.decodeIfPresent(Bool.self, forKey: .showsCalendar)
        isSample = try container.decodeIfPresent(Bool.self, forKey: .isSample) ?? false
    }
}

extension ReminderLiveActivityAttributes.ContentState {
    /// `id` 항목을 제거한 새 상태. LA에서 체크(완료)한 항목을 숨길 때 쓴다.
    /// 표시 카운트(`items.count + remaining`)는 항목이 빠진 만큼 자동으로 줄어든다.
    /// `remaining`은 그대로 둔다 — 잘려나간 나머지 항목의 데이터가 LA엔 없어 backfill 불가.
    /// 실제로 항목이 빠졌으면 `todayCount`도 1 줄인다 — 완료한 할일은 오늘 카운트에서 빠지므로.
    func removingItem(id: String) -> Self {
        var copy = self
        copy.items.removeAll { $0.id == id }
        if copy.items.count != items.count {
            copy.todayCount = max(0, todayCount - 1)
        }
        return copy
    }
}
