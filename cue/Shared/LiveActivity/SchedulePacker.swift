//
//  SchedulePacker.swift
//  cue / Shared
//

import Foundation
import UIKit

/// 한 열에 들어가는 한 묶음 — 같은 날이 두 열로 나뉘면 두 번째 묶음은 `label == nil`(헤더 생략).
struct DayChunk: Identifiable, Equatable {
    let id: String
    let label: String?
    let events: [LiveEventItem]
}

/// 일정 LA 2열 배치 로직 — 위젯 렌더와 분리해 단위 테스트 가능하게 둔다.
enum SchedulePacker {
    /// 이벤트 단위로 **왼쪽 열부터 꽉 채우고** 넘치면 오른쪽으로 보낸다(둘 다 차면 버림).
    /// 한 날이 한 열에 다 안 들어가면 거기까지 넣고, 다음 열에서 **이어** 그린다. 단 **헤더(날짜
    /// 라벨)는 그 날의 첫 청크에만** 표시한다 — 오른쪽 연속분은 헤더 없이 이벤트만(중복 방지).
    static func pack(_ days: [LiveScheduleDay]) -> (left: [DayChunk], right: [DayChunk]) {
        let cols = pack(days, columnCount: 2)
        return (cols[0], cols[1])
    }

    /// 캘린더 함께 표시 레이아웃의 오른쪽 반쪽용 — 한 컬럼 높이에 들어가는 만큼만(넘치면 버림).
    /// 2열 패킹과 같은 채움 규칙을 공유하므로 결과는 `pack`의 왼쪽 열과 동일하다.
    static func packSingleColumn(_ days: [LiveScheduleDay]) -> [DayChunk] {
        pack(days, columnCount: 1)[0]
    }

    /// 공통 채움 루프 — `columnCount`개 열을 차례로 채운다.
    private static func pack(_ days: [LiveScheduleDay], columnCount: Int) -> [[DayChunk]] {
        var cols: [[DayChunk]] = Array(repeating: [], count: columnCount)
        var col = 0
        var used: CGFloat = 0

        outer: for day in days {
            var index = 0
            var isFirstChunk = true
            while index < day.events.count {
                if col >= columnCount { break outer }

                let showsHeader = isFirstChunk
                var chunk: [LiveEventItem] = []
                while index < day.events.count {
                    let event = day.events[index]
                    let inc: CGFloat
                    if chunk.isEmpty {
                        let lead = used > 0 ? ScheduleMetrics.dayGap : 0
                        let head = showsHeader ? ScheduleMetrics.header + ScheduleMetrics.rowGap : 0
                        inc = lead + head + ScheduleMetrics.eventHeight(event)
                    } else {
                        inc = ScheduleMetrics.rowGap + ScheduleMetrics.eventHeight(event)
                    }
                    if used + inc <= ScheduleMetrics.columnMax {
                        used += inc
                        chunk.append(event)
                        index += 1
                    } else {
                        break
                    }
                }

                if chunk.isEmpty {
                    // 현재 열에 더는 못 넣음 → 다음 열로.
                    col += 1
                    used = 0
                    continue
                }

                cols[col].append(DayChunk(id: "\(day.id)-\(col)", label: showsHeader ? day.label : nil, events: chunk))
                isFirstChunk = false
                if index < day.events.count {
                    // 이 날이 남았다 → 열을 닫고 다음 열에서 헤더 없이 이어 그린다.
                    col += 1
                    used = 0
                }
            }
        }
        return cols
    }
}

/// 일정 행 높이 추정 + 레이아웃 간격을 한곳에 모은다 — 패커 계산과 실제 뷰 간격이 항상 일치하게.
///
/// **잠금화면 Live Activity 최대 높이 = 160pt**(시스템이 초과분을 잘라냄, 디바이스 공통).
/// `columnMax = 160 − 상하 패딩(outerPadding × 2)`로 두면 패커가 컬럼 콘텐츠를 이 값 이하로
/// 잘라 **총높이 ≤ 160pt가 보장**된다. caption/caption2 + 좁은 간격 기준 컬럼당 시간 이벤트
/// 3개(종일은 더) 정도 들어간다.
enum ScheduleMetrics {
    /// 위젯 상하 패딩 — 이 값이 바뀌면 columnMax(높이 예산)가 자동으로 따라간다.
    static let outerPadding: CGFloat = Spacing.smd      // 12
    /// 위젯 좌우 패딩 — 높이 예산과 무관.
    static let outerHorizontalPadding: CGFloat = Spacing.md    // 16
    /// 두 열 사이 간격 — HStack spacing이라 디바이더 양옆에 각각 적용된다.
    static let columnGap: CGFloat = Spacing.smd         // 12
    /// 컬럼 내 날짜 묶음 사이 간격 — 160pt 예산에 한 줄이라도 더 들어가게 조밀하게.
    static let dayGap: CGFloat = Spacing.xs             // 4
    /// 헤더↔이벤트 / 이벤트 사이 간격 — 한글 줄박스가 커서(caption2 하한 11pt도 15.1pt)
    /// 텍스트로는 더 못 줄이므로 크롬에서 회수한다.
    static let rowGap: CGFloat = Spacing.xxs            // 2

    /// 줄높이는 **xSmall 콘텐츠 크기로 고정해** 읽는다 — iOS 26의 표준(.large) 타입 램프가
    /// 커져(caption1 실측 16.3, 이전 14.3) 잠금화면 예산 136pt에 행이 몇 개 못 들어간다.
    /// 뷰가 `.dynamicTypeSize(.xSmall)`로 렌더를 고정하므로, 추정도 같은 카테고리로 고정해
    /// 추정=렌더를 유지한다(어긋나면 조기 마감·잘림이 재발 — 실기기 진단 오버레이로 확정한 이력).
    private static let defaultTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)
    static var titleLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: defaultTraits).lineHeight
    }
    static var timeLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: defaultTraits).lineHeight
    }
    /// 날짜 헤더는 caption2로 렌더 — 뷰(ScheduleDayView)와 동기.
    static var header: CGFloat { timeLine }
    static func eventHeight(_ event: LiveEventItem) -> CGFloat {
        // 별도 글리프 마진 없음 — preferredFont 줄높이가 이미 한글 시스템 폰트의 큰 줄박스
        // (11pt→15.1)를 반영한 렌더 실측이라, 마진을 더하면 예산만 이중으로 깎인다.
        event.isAllDay
            ? titleLine + Spacing.xxs * 2   // 캡슐 상하 패딩(2) — 뷰(ScheduleEventRow)와 동기
            : titleLine + timeLine          // 제목 + 시간 두 줄(간격 없음)
    }

    /// 160pt(시스템 최대) − 상하 패딩.
    static var columnMax: CGFloat { 160 - outerPadding * 2 }
}
