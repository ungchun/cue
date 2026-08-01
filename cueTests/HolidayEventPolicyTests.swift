//
//  HolidayEventPolicyTests.swift
//  cueTests
//

import Testing
@testable import cue

struct HolidayEventPolicyTests {

    // MARK: - 공휴일로 인정하는 경우

    @Test func subscribedReadOnlyAllDayEventIsHoliday() {
        // iOS 기본 "대한민국 공휴일" 캘린더 — 구독형 + 읽기 전용 + 종일.
        #expect(HolidayEventPolicy.isHoliday(
            isSubscribed: true, allowsContentModifications: false, isAllDay: true
        ))
    }

    @Test func anyRegionHolidayCalendarQualifies() {
        // 판정에 나라 개념이 없다 — 독일 공휴일 캘린더도 같은 조건이면 그대로 통과한다.
        // 이게 이 정책의 존재 이유다(예전 KoreanHolidayCalculator는 한국만 알았다).
        #expect(HolidayEventPolicy.isHoliday(
            isSubscribed: true, allowsContentModifications: false, isAllDay: true
        ))
    }

    // MARK: - 배제하는 경우

    @Test func timedEventInSubscribedCalendarIsNotHoliday() {
        // 스포츠 일정 같은 구독 캘린더는 대부분 시각이 있다 — 종일이 아니면 공휴일이 아니다.
        // 이 조건이 구독 캘린더 오검출을 막는 주된 방어선이다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: true, allowsContentModifications: false, isAllDay: false
        ))
    }

    @Test func ownCalendarAllDayEventIsNotHoliday() {
        // 내가 만든 종일 일정(휴가·출장)이 날짜를 빨갛게 만들면 안 된다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: false, allowsContentModifications: true, isAllDay: true
        ))
    }

    @Test func writableSubscribedCalendarIsNotHoliday() {
        // 공휴일 캘린더는 사용자가 고칠 수 없다 — 쓰기가 열려 있으면 공유 캘린더 쪽이다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: true, allowsContentModifications: true, isAllDay: true
        ))
    }

    @Test func readOnlyButNotSubscribedIsNotHoliday() {
        // 생일 캘린더(.birthday)가 여기 걸린다 — 읽기 전용이지만 구독이 아니다.
        // 생일마다 날짜가 빨개지면 안 된다.
        #expect(!HolidayEventPolicy.isHoliday(
            isSubscribed: false, allowsContentModifications: false, isAllDay: true
        ))
    }
}
