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
        var cols: [[DayChunk]] = [[], []]
        var col = 0
        var used: CGFloat = 0

        outer: for day in days {
            var index = 0
            var isFirstChunk = true
            while index < day.events.count {
                if col >= 2 { break outer }

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
        return (cols[0], cols[1])
    }
}

/// 일정 행 높이 추정 + 레이아웃 간격을 한곳에 모은다 — 패커 계산과 실제 뷰 간격이 항상 일치하게.
///
/// **잠금화면 Live Activity 최대 높이 = 160pt**(시스템이 초과분을 잘라냄, 디바이스 공통).
/// `columnMax = 160 − 상하 패딩(outerPadding × 2)`로 두면 패커가 컬럼 콘텐츠를 이 값 이하로
/// 잘라 **총높이 ≤ 160pt가 보장**된다. caption/caption2 + 좁은 간격 기준 컬럼당 시간 이벤트
/// 3개(종일은 더) 정도 들어간다.
enum ScheduleMetrics {
    /// 위젯 상하좌우 패딩.
    static let outerPadding: CGFloat = Spacing.smd      // 12
    /// 두 열 사이 간격.
    static let columnGap: CGFloat = Spacing.md          // 16
    /// 컬럼 내 날짜 묶음 사이 간격.
    static let dayGap: CGFloat = Spacing.sm             // 8
    /// 헤더↔이벤트 / 이벤트 사이 간격.
    static let rowGap: CGFloat = Spacing.xs             // 4

    static var titleLine: CGFloat { UIFont.preferredFont(forTextStyle: .caption1).lineHeight }
    static var timeLine: CGFloat { UIFont.preferredFont(forTextStyle: .caption2).lineHeight }
    static var header: CGFloat { titleLine }

    static func eventHeight(_ event: LiveEventItem) -> CGFloat {
        event.isAllDay
            ? titleLine + Spacing.xs * 2           // 캡슐 상하 패딩
            : titleLine + Spacing.xxs + timeLine   // 제목 + 시간 두 줄
    }

    /// 160pt(시스템 최대) − 상하 패딩.
    static var columnMax: CGFloat { 160 - outerPadding * 2 }
}
