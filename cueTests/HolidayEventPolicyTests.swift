//
//  HolidayEventPolicyTests.swift
//  cueTests
//

import Testing
@testable import cue

struct HolidayEventPolicyTests {

    // MARK: - 빨간색을 칠할 지역인가

    @Test func koreaShowsHolidayColor() {
        #expect(HolidayEventPolicy.showsHolidayColor(regionCode: "KR"))
    }

    @Test func otherRegionsDoNotShowHolidayColor() {
        // 애플 공휴일 캘린더의 내용이 지역마다 달라 한국 밖에서는 신뢰할 수 없다 —
        // 미국은 밸런타인데이·핼러윈, 대만은 24절기까지 같은 캘린더에 들어 있다.
        for region in ["US", "TW", "CN", "JP", "DE", "GB"] {
            #expect(
                !HolidayEventPolicy.showsHolidayColor(regionCode: region),
                "\(region)에서 빨간날이 켜지면 안 된다"
            )
        }
    }

    @Test func koreanHolidaySubscriptionAbroadStaysUncolored() {
        // 대만·미국 사용자가 한국 공휴일 캘린더를 구독하고 있어도 빨갛게 칠하지 않는다.
        // 판정(`isHoliday`)은 통과해도 표시(`showsHolidayColor`)에서 막힌다.
        #expect(HolidayEventPolicy.isHoliday(
            isSubscribed: true, isSubscriptionType: true,
            allowsContentModifications: false, isAllDay: true
        ))
        #expect(!HolidayEventPolicy.showsHolidayColor(regionCode: "TW"))
    }

    @Test func unknownRegionDoesNotShowHolidayColor() {
        // 지역을 못 읽으면 끈다 — 켜는 쪽이 기본값이면 엉뚱한 나라에서 빨개진다.
        #expect(!HolidayEventPolicy.showsHolidayColor(regionCode: nil))
    }

    @Test func regionCodeIsCaseInsensitive() {
        // `Locale.Region.identifier`는 대문자를 주지만, 소문자로 오는 경로가 생겨도 같게 본다.
        #expect(HolidayEventPolicy.showsHolidayColor(regionCode: "kr"))
    }


    // MARK: - 공휴일로 인정하는 경우

    @Test func subscriptionTypeReadOnlyAllDayEventIsHoliday() {
        // `type == .subscription`으로 들어오는 경우 — 애플 지원 문서가 공휴일 캘린더를
        // "subscription calendar"라고 부르는 그 형태.
        #expect(HolidayEventPolicy.isHoliday(
            isSubscribed: false, isSubscriptionType: true,
            allowsContentModifications: false, isAllDay: true
        ))
    }

    @Test func calDAVSubscribedReadOnlyAllDayEventIsHoliday() {
        // CalDAV로 들어오며 isSubscribed만 서는 경우 — 애플 문서: "CalDAV subscribed
        // calendars have type EKCalendarTypeCalDAV with isSubscribed = YES".
        // 기본 공휴일 캘린더가 기기에서 어느 쪽으로 오는지 확정할 수 없어 둘 다 통과시킨다.
        #expect(HolidayEventPolicy.isHoliday(
            isSubscribed: true, isSubscriptionType: false,
            allowsContentModifications: false, isAllDay: true
        ))
    }

    // MARK: - 배제하는 경우

    @Test func timedEventInSubscribedCalendarIsNotHoliday() {
        // 스포츠 일정 같은 구독 캘린더는 대부분 시각이 있다 — 종일이 아니면 공휴일이 아니다.
        // 이 조건이 구독 캘린더 오검출을 막는 주된 방어선이다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: true, isSubscriptionType: true,
            allowsContentModifications: false, isAllDay: false
        ))
    }

    @Test func ownCalendarAllDayEventIsNotHoliday() {
        // 내가 만든 종일 일정(휴가·출장)이 날짜를 빨갛게 만들면 안 된다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: false, isSubscriptionType: false,
            allowsContentModifications: true, isAllDay: true
        ))
    }

    @Test func writableSubscribedCalendarIsNotHoliday() {
        // 공휴일 캘린더는 사용자가 고칠 수 없다 — 쓰기가 열려 있으면 공유 캘린더 쪽이다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: true, isSubscriptionType: true,
            allowsContentModifications: true, isAllDay: true
        ))
    }

    @Test func readOnlyButNotSubscribedIsNotHoliday() {
        // 생일 캘린더(.birthday)가 여기 걸린다 — 읽기 전용이지만 구독이 아니다.
        // 생일마다 날짜가 빨개지면 안 된다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: false, isSubscriptionType: false,
            allowsContentModifications: false, isAllDay: true
        ))
    }
}
