//
//  HolidayEventPolicyTests.swift
//  cueTests
//

import Testing
@testable import cue

struct HolidayEventPolicyTests {

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
