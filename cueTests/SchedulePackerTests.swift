//
//  SchedulePackerTests.swift
//  cueTests
//

import Foundation
import Testing
@testable import cue

struct SchedulePackerTests {

    private func day(id: String, label: String, count: Int, allDay: Bool = false) -> LiveScheduleDay {
        let events = (0..<count).map { i in
            LiveEventItem(
                id: "\(id)-\(i)",
                title: "이벤트 \(i)",
                startDate: Date(timeIntervalSince1970: Double(i * 3600)),
                endDate: Date(timeIntervalSince1970: Double(i * 3600 + 1800)),
                timeText: "",
                calendarColorHex: nil,
                isAllDay: allDay
            )
        }
        return LiveScheduleDay(id: id, label: label, events: events)
    }

    /// 행 종류 조합별 간격 계약 — 뷰(ScheduleDayView.topGap)와 패커가 공유하는 규칙.
    /// 캡슐끼리 6 > 캡슐↔시간·시간끼리 4 — 배경 경계가 선명할수록 넉넉히.
    @Test func rowGapDependsOnAdjacentRowKinds() {
        let capsule = day(id: "a", label: "오늘", count: 1, allDay: true).events[0]
        let timed = day(id: "t", label: "오늘", count: 1).events[0]

        #expect(ScheduleMetrics.rowGap(previous: capsule, next: capsule) == 6)
        #expect(ScheduleMetrics.rowGap(previous: capsule, next: timed) == Spacing.xs)
        #expect(ScheduleMetrics.rowGap(previous: timed, next: capsule) == Spacing.xs)
        #expect(ScheduleMetrics.rowGap(previous: timed, next: timed) == Spacing.xs)
    }

    /// 종일 캡슐만으로도 패킹이 정상 동작한다 — 조합별 간격 도입 후 회귀 방지.
    @Test func packsAllDayOnlyDays() {
        let (left, right) = SchedulePacker.pack([
            day(id: "a", label: "오늘", count: 2, allDay: true),
            day(id: "b", label: "내일", count: 1, allDay: true),
        ])

        let placed = (left + right).flatMap { $0.events.map(\.id) }
        #expect(placed == ["a-0", "a-1", "b-0"])
    }

    @Test func emptyDaysProduceEmptyColumns() {
        let (left, right) = SchedulePacker.pack([])
        #expect(left.isEmpty)
        #expect(right.isEmpty)
    }

    @Test func fewEventsAllGoLeftAndRightStaysEmpty() {
        let (left, right) = SchedulePacker.pack([day(id: "d", label: "오늘", count: 1)])

        #expect(right.isEmpty)               // 적으면 오른쪽 안 씀
        #expect(left.count == 1)
        #expect(left.first?.label == "오늘")  // 첫(유일) 청크에 헤더
        #expect(left.first?.events.count == 1)
    }

    @Test func multipleSmallDaysStackInLeft() {
        let (left, right) = SchedulePacker.pack([
            day(id: "a", label: "오늘", count: 1),
            day(id: "b", label: "내일", count: 1),
        ])

        #expect(right.isEmpty)
        #expect(left.map(\.label) == ["오늘", "내일"])
    }

    @Test func overflowingDaySplitsToRightWithoutRepeatingHeader() {
        // 한 날에 많은 이벤트 → 두 열을 다 채우고 넘침.
        let (left, right) = SchedulePacker.pack([day(id: "big", label: "오늘", count: 40)])

        #expect(!left.isEmpty)
        #expect(!right.isEmpty)
        #expect(left.first?.label == "오늘")            // 왼쪽 첫 청크에만 헤더
        #expect(right.allSatisfy { $0.label == nil })   // 오른쪽 연속분은 헤더 생략

        // 이벤트 순서 보존 + 중복 없음 + 원본의 앞부분(prefix).
        let placed = left.flatMap { $0.events.map(\.id) } + right.flatMap { $0.events.map(\.id) }
        #expect(Set(placed).count == placed.count)
        #expect(placed == (0..<40).map { "big-\($0)" }.prefix(placed.count).map { $0 })
    }

    /// 실기기 실측 회귀(2026-07 진단) — "오늘 2·내일 2·모레 1" 시나리오는 두 열에 **전부** 들어간다.
    /// 실측: 헤더 15.2 / 시간행 30.9 → 컬럼당 (헤더+2행) 83pt + 다음 날 첫 행 52.1 = 135.1 ≤ 136.
    /// 과거엔 caption2 스타일 메트릭(리딩 포함 15.1)을 크기비 스케일해 행당 ~4.3pt 과대 추정
    /// → 셋째 날이 통째로 버려졌다(레퍼런스 대비 휑한 카드).
    @Test func fiveRowsAcrossThreeDaysAllFitLikeReference() {
        let (left, right) = SchedulePacker.pack([
            day(id: "a", label: "오늘", count: 2),
            day(id: "b", label: "내일", count: 2),
            day(id: "c", label: "모레", count: 1),
        ])

        let placed = (left + right).flatMap { $0.events.map(\.id) }
        #expect(placed.count == 5)
    }

    /// 추정 캘리브레이션 가드 — 시간 행 추정은 실측(30.9pt)을 과소하지 않되(잘림 위험)
    /// 2pt 이상 과대하지도 않아야 한다(행 버림 재발). 종일 캡슐 실측은 19.1pt.
    @Test func estimatesStayWithinMeasuredBounds() {
        let timed = day(id: "t", label: "오늘", count: 1).events[0]
        let allDay = day(id: "a", label: "오늘", count: 1, allDay: true).events[0]

        #expect(ScheduleMetrics.eventHeight(timed) >= 30.9)
        #expect(ScheduleMetrics.eventHeight(timed) <= 32.9)
        #expect(ScheduleMetrics.eventHeight(allDay) >= 19.1)
        #expect(ScheduleMetrics.eventHeight(allDay) <= 21.1)
    }

    /// 톨 스크립트(태국어·데바나가리·아랍어·베트남어)는 라틴 lineHeight보다 캐스케이드가
    /// 커서 행 마진을 넉넉히 — 그 외(한글·라틴)는 실측 기반 0.4 유지(밀도 보존).
    @Test func rowSafetyMarginScalesForTallScripts() {
        for code in ["th", "hi", "ar", "vi"] {
            #expect(ScheduleMetrics.rowSafetyMargin(languageCode: code) == 2.0)
        }
        for code in ["ko", "en", "ja", "zh"] {
            #expect(ScheduleMetrics.rowSafetyMargin(languageCode: code) == 0.4)
        }
        #expect(ScheduleMetrics.rowSafetyMargin(languageCode: nil) == 0.4)
    }

    // MARK: - 단일 컬럼 (캘린더 함께 표시 시 오른쪽 반쪽)

    /// 적은 이벤트는 헤더와 함께 그대로 들어간다.
    @Test func singleColumnKeepsFewEventsWithHeader() {
        let chunks = SchedulePacker.packSingleColumn([day(id: "d", label: "오늘", count: 1)])

        #expect(chunks.count == 1)
        #expect(chunks.first?.label == "오늘")
        #expect(chunks.first?.events.count == 1)
    }

    /// 넘치는 이벤트는 한 컬럼 높이(columnMax)에서 잘린다 — 이어 그릴 두 번째 열이 없다.
    @Test func singleColumnTruncatesOverflow() {
        let chunks = SchedulePacker.packSingleColumn([day(id: "big", label: "오늘", count: 40)])

        let placed = chunks.flatMap { $0.events.map(\.id) }
        #expect(placed.count < 40)                     // 다 못 들어간다
        #expect(placed == (0..<placed.count).map { "big-\($0)" })   // 순서 보존 prefix
    }

    /// 단일 컬럼은 2열 패킹의 왼쪽 열과 동일하다 — 같은 채움 규칙을 공유한다.
    @Test func singleColumnMatchesLeftColumnOfTwoColumnPack() {
        let days = [
            day(id: "a", label: "오늘", count: 2),
            day(id: "b", label: "내일", count: 3),
            day(id: "c", label: "모레", count: 3),
        ]

        let single = SchedulePacker.packSingleColumn(days)
        let (left, _) = SchedulePacker.pack(days)

        #expect(single == left)
    }
}
