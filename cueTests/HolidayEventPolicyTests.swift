//
//  HolidayEventPolicyTests.swift
//  cueTests
//

import Testing
@testable import cue

struct HolidayEventPolicyTests {

    private let koreanHolidays = "대한민국 공휴일"

    private func shows(
        region: String? = "KR",
        title: String? = nil,
        isAllDay: Bool = true
    ) -> Bool {
        HolidayEventPolicy.showsAsHoliday(
            regionCode: region,
            calendarTitle: title ?? koreanHolidays,
            isAllDay: isAllDay
        )
    }

    // MARK: - 통과하는 경우

    @Test func koreanHolidayCalendarAllDayEventShows() {
        #expect(shows())
    }

    @Test func deviceLanguageDoesNotMatter() {
        // 애플은 한국 공휴일을 **한국어판 하나로만** 배포한다(kr_ko만 존재, kr_en·kr_ja·kr_zh는
        // 404). 그래서 기기 언어가 영어여도 캘린더 제목은 "대한민국 공휴일" 그대로다 —
        // 판정에 언어가 등장하지 않는 근거.
        #expect(shows(region: "kr"))
    }

    // MARK: - 막는 경우

    @Test func otherSubscribedCalendarsDoNotShow() {
        // 예전 판정(구독형 + 읽기전용 + 종일)은 이것들을 전부 통과시켰다 — 제목으로 좁혀
        // 오검출을 없앤다.
        for title in ["학사일정", "회사 일정", "사내 휴무일", "절기달력", "프로야구 일정"] {
            #expect(!shows(title: title), "\(title)이 공휴일로 잡히면 안 된다")
        }
    }

    @Test func otherCountriesHolidayCalendarsDoNotShow() {
        // 한국 기기에서 일본·미국·대만 공휴일 캘린더를 구독해도 빨갛게 칠하지 않는다.
        // 실제 애플 캘린더 제목들이다.
        for title in ["日本の祝日", "Japan Holidays", "US Holidays", "台灣節日"] {
            #expect(!shows(title: title), "\(title)이 한국에서 빨개지면 안 된다")
        }
    }

    @Test func timedEventDoesNotShow() {
        // 공휴일은 하루 전체다. 같은 캘린더에 시각 있는 항목이 들어와도 날짜를 칠하지 않는다.
        #expect(!shows(isAllDay: false))
    }

    @Test func otherRegionsDoNotShow() {
        // 미국(밸런타인데이·핼러윈·Daylight Saving Time)과 대만(24절기 24개)은 공휴일
        // 캘린더에 안 쉬는 날이 대량으로 섞여 있어 켜지 않는다 — 애플 원본 ICS로 확인.
        for region in ["US", "TW", "JP", "CN", "DE", "GB"] {
            #expect(!shows(region: region), "\(region)에서 빨간날이 켜지면 안 된다")
        }
    }

    @Test func unknownRegionDoesNotShow() {
        // 지역을 못 읽으면 끈다 — 켜는 쪽이 기본값이면 엉뚱한 나라에서 빨개진다.
        #expect(!shows(region: nil))
    }
}
