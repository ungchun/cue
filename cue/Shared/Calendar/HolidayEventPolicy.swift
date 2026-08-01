//
//  HolidayEventPolicy.swift
//  cue / Shared
//

import Foundation

/// 캘린더 이벤트 하나를 **공휴일로 볼지** 판정한다 — 달력의 날짜 숫자를 빨갛게 칠할지의 근거.
///
/// 예전엔 한국 법정공휴일을 코드로 직접 계산했다(`KoreanHolidayCalculator`). 그 방식은
/// 사용자가 어느 나라에 있든 한국 날짜를 빨갛게 칠했고, 정작 사용자가 구독한 그 나라
/// 공휴일 캘린더는 무시했다. 이제는 **사용자의 캘린더가 답을 갖고 있다** — iOS가 기본으로
/// 켜 주는 "대한민국 공휴일" / "Feiertage in Deutschland" 같은 구독 캘린더가 그것이다.
///
/// EventKit에는 "이건 공휴일 캘린더"라는 플래그가 없다(`EKCalendarType`에 `.holiday`가
/// 없다). 그래서 세 조건의 교집합으로 좁힌다:
///
/// - **구독형** — 공휴일 캘린더는 사용자가 만든 게 아니라 받아 온 것이다.
/// - **읽기 전용**(`!allowsContentModifications`) — 공휴일은 사용자가 고칠 수 없다.
///   생일 캘린더도 읽기 전용이지만 구독이 아니라 위 조건에서 걸러진다.
/// - **종일**(`isAllDay`) — 공휴일은 하루 전체다. 스포츠 일정처럼 구독형 읽기 전용이면서
///   시각이 있는 캘린더가 날짜를 빨갛게 만드는 걸 막는 주된 방어선이다.
///
/// 애플 지원 문서가 앞의 두 조건을 그대로 확인해 준다 — "The Holidays calendar is a
/// **subscription calendar**, and you can't add or delete holidays, because subscription
/// calendars **can be modified only by the calendar provider**." 지역도 기기 설정을
/// 따라가므로(한국이면 "대한민국 공휴일", 독일이면 "Feiertage in Deutschland") 이 정책에는
/// 나라 개념이 필요 없다.
///
/// ⚠️ **구독형을 두 신호의 OR로 본다.** EventKit이 구독 캘린더를 표현하는 방식이 둘이라서다:
/// `type == .subscription`인 경우와, CalDAV로 들어오면서 `isSubscribed == true`만 서는 경우
/// (애플 문서: "CalDAV subscribed calendars have type EKCalendarTypeCalDAV with
/// isSubscribed = YES"). iOS 기본 공휴일 캘린더가 기기에서 정확히 어느 쪽으로 오는지는
/// 공개 문서로 확정되지 않아, 한쪽에만 걸어두면 조용히 실패한다 — 둘 중 하나면 통과시킨다.
/// 두 신호 모두 "사용자가 만들지 않고 받아 온 캘린더"를 뜻하므로 OR로 넓혀도 의미가 흐려지지
/// 않는다.
///
/// 순수 함수다 — EventKit을 import하지 않는다. 호출부(`WidgetCalendarDataSource`,
/// `LiveMonthCalendarProvider`)가 `EKEvent`에서 값을 꺼내 넘긴다.
enum HolidayEventPolicy {

    static func isHoliday(
        isSubscribed: Bool,
        isSubscriptionType: Bool,
        allowsContentModifications: Bool,
        isAllDay: Bool
    ) -> Bool {
        (isSubscribed || isSubscriptionType) && !allowsContentModifications && isAllDay
    }
}
