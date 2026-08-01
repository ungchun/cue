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
/// calendars **can be modified only by the calendar provider**." 어느 나라 공휴일이 담기는지도
/// 기기 지역 설정을 따라간다(한국이면 "대한민국 공휴일", 독일이면 "Feiertage in Deutschland")
/// — 그래서 **이 판정 자체에는 나라 이름이 등장하지 않는다.** 나라를 보는 건 아래 표시 결정
/// (`showsHolidayColor`)뿐이다.
///
/// ⚠️ **구독형을 두 신호의 OR로 본다.** EventKit이 구독 캘린더를 표현하는 방식이 둘이라서다:
/// `type == .subscription`인 경우와, CalDAV로 들어오면서 `isSubscribed == true`만 서는 경우
/// (애플 문서: "CalDAV subscribed calendars have type EKCalendarTypeCalDAV with
/// isSubscribed = YES"). iOS 기본 공휴일 캘린더가 기기에서 정확히 어느 쪽으로 오는지는
/// 공개 문서로 확정되지 않아, 한쪽에만 걸어두면 조용히 실패한다 — 둘 중 하나면 통과시킨다.
/// 두 신호 모두 "사용자가 만들지 않고 받아 온 캘린더"를 뜻하므로 OR로 넓혀도 의미가 흐려지지
/// 않는다.
///
/// ## ⚠️ 알려진 한계 — 이 판정은 "쉬는 날"이 아니라 "공휴일 캘린더에 있는 날"이다
///
/// 애플의 기본 공휴일 캘린더는 **지역마다 담긴 내용이 다르다**. 법정공휴일만 담긴 곳도 있고,
/// 쉬지 않는 기념일까지 담긴 곳도 있다. 조사로 확인된 것:
///
/// - **한국** — 대체로 법정공휴일만. 다만 **대체공휴일이 빠진다**(애플이 안 넣는다).
///   예전 `KoreanHolidayCalculator`는 대체공휴일을 계산했으므로 그만큼은 후퇴다.
/// - **미국** — 연방 공휴일 10일 외에 밸런타인데이·핼러윈·성촌절(Groundhog Day) 같은
///   **쉬지 않는 기념일**이 함께 들어 있다. 전부 종일이라 이 판정을 통과한다.
/// - **대만** — 「台灣節日」은 국정휴일과 다르다. 원소절·부녀절 등 쉬지 않는 명절에 더해
///   **24절기까지** 들어 있다. 이 판정만으로는 한 해 40일 넘게 빨갛게 칠해진다.
///
/// EventKit에는 "이건 쉬는 날"과 "이건 기념일"을 가르는 신호가 없다 — `EKCalendar`의 비공개
/// 속성 `isSubscribedHolidayCalendar`가 존재하지만 공개 SDK에 없어 쓸 수 없다. 즉 코드로는
/// 더 좁힐 수 없다.
///
/// **그래서 빨간색 자체를 한국에서만 켠다**(→ `showsHolidayColor(regionCode:)`).
/// 대만·미국 사용자는 공휴일 캘린더를 구독하고 있어도 날짜가 빨개지지 않는다.
///
/// 순수 함수다 — EventKit을 import하지 않는다. 호출부(`WidgetCalendarDataSource`,
/// `LiveMonthCalendarProvider`)가 `EKEvent`에서 값을 꺼내 넘긴다.
enum HolidayEventPolicy {

    /// 빨간날을 켜는 지역. 지금은 한국뿐이다.
    ///
    /// 확장하려면 그 지역의 공휴일 캘린더에 **쉬지 않는 날이 섞여 있지 않은지 먼저 확인**해야
    /// 한다. 대만을 넣으면 24절기가, 미국을 넣으면 밸런타인데이가 함께 빨개진다(위 한계 참고).
    private static let coloredRegions: Set<String> = ["KR"]

    /// 이 기기에서 공휴일을 빨간색으로 칠할지.
    ///
    /// **판정(`isHoliday`)과 표시를 분리한 이유**: 어떤 날이 공휴일 캘린더에 있느냐는 사실이고,
    /// 그걸 빨갛게 칠하느냐는 지역 관습이다. 둘을 섞으면 "대만 사용자가 한국 공휴일 캘린더를
    /// 구독했을 때" 같은 조합에서 판정이 통과해 빨개진다.
    ///
    /// 기준은 **기기 지역**(설정 > 일반 > 언어 및 지역 > 지역)이다. 언어가 아니라 지역인 이유는
    /// 애플이 공휴일 캘린더를 고르는 기준이 바로 이 값이라서다 — 같은 값을 봐야 "화면에 뜨는
    /// 공휴일"과 "빨갛게 칠할지"가 어긋나지 않는다.
    ///
    /// 지역을 못 읽으면 **끈다**. 켜는 쪽이 기본값이면 엉뚱한 나라에서 빨간날이 뜬다.
    static func showsHolidayColor(regionCode: String?) -> Bool {
        guard let regionCode else { return false }
        return coloredRegions.contains(regionCode.uppercased())
    }

    /// 현재 기기 기준 — 위젯·LA 익스텐션에서도 시스템 지역 설정을 그대로 따라간다.
    static var showsHolidayColorHere: Bool {
        showsHolidayColor(regionCode: Locale.current.region?.identifier)
    }

    static func isHoliday(
        isSubscribed: Bool,
        isSubscriptionType: Bool,
        allowsContentModifications: Bool,
        isAllDay: Bool
    ) -> Bool {
        (isSubscribed || isSubscriptionType) && !allowsContentModifications && isAllDay
    }
}
