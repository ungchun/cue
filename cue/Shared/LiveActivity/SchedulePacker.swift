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
    /// 위젯 상하좌우 패딩.
    static let outerPadding: CGFloat = Spacing.smd      // 12
    /// 두 열 사이 간격.
    static let columnGap: CGFloat = Spacing.md          // 16
    /// 컬럼 내 날짜 묶음 사이 간격 — 160pt 예산에 한 줄이라도 더 들어가게 조밀하게.
    static let dayGap: CGFloat = Spacing.xs             // 4
    /// 헤더↔이벤트 / 이벤트 사이 간격.
    static let rowGap: CGFloat = Spacing.xs             // 4

    /// 줄높이는 **기본(large) 콘텐츠 크기로 고정해** 읽는다 — 위젯 익스텐션 프로세스의
    /// `preferredFont`는 기기 글자 크기가 기본이어도 부풀려진 값(실측 16.3/15.1)을 돌려줘,
    /// 실제 렌더(≈14.3/13.1 스케일)보다 행을 크게 추정 → 패커가 예산을 30~40pt 남기고도
    /// 조기 마감해 뒷날 일정이 통째로 잘렸다(실기기 진단 오버레이로 확정).
    private static let defaultTraits = UITraitCollection(preferredContentSizeCategory: .large)
    static var titleLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption1, compatibleWith: defaultTraits).lineHeight
    }
    static var timeLine: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: defaultTraits).lineHeight
    }
    /// 날짜 헤더는 caption2로 렌더 — 뷰(ScheduleDayView)와 동기.
    static var header: CGFloat { timeLine }
    /// CJK·이모지 제목은 SF 추정보다 줄이 ~2pt 크게 렌더된다 — 이벤트당 안전 마진.
    /// 없으면 딱 맞게 채운 열이 실렌더에서 1~2pt 넘쳐 마지막 줄이 잘릴 수 있다.
    static let glyphMargin: CGFloat = Spacing.xxs

    static func eventHeight(_ event: LiveEventItem) -> CGFloat {
        let base = event.isAllDay
            ? titleLine + Spacing.xxs * 2   // 캡슐 상하 패딩(2) — 뷰(ScheduleEventRow)와 동기
            : titleLine + timeLine          // 제목 + 시간 두 줄(간격 없음)
        return base + glyphMargin
    }

    /// 160pt(시스템 최대) − 상하 패딩.
    static var columnMax: CGFloat { 160 - outerPadding * 2 }
}

extension SchedulePacker {
    /// ⚠️ 임시 진단 — 잠금화면 카드에 패킹 산술을 그대로 노출하기 위한 요약.
    /// (며칠/몇 개가 실렸는지 · 각 열 추정 사용 높이 · 예산 · 줄높이) 원인 확정 후 제거한다.
    static func debugSummary(_ days: [LiveScheduleDay]) -> String {
        let (left, right) = pack(days)
        let m = ScheduleMetrics.self
        return "\(days.count)d/\(days.flatMap(\.events).count)e"
            + " L\(Int(columnHeight(left))) R\(Int(columnHeight(right)))"
            + " max\(Int(m.columnMax))"
            + String(format: " t%.1f s%.1f", m.titleLine, m.timeLine)
            + " g\(Int(m.dayGap))"
    }

    /// 임시 진단용 — 패킹 결과 한 열의 추정 사용 높이(패커와 같은 산술).
    private static func columnHeight(_ chunks: [DayChunk]) -> CGFloat {
        var used: CGFloat = 0
        for (index, chunk) in chunks.enumerated() {
            if index > 0 || chunks.first?.label == nil { used += used > 0 ? ScheduleMetrics.dayGap : 0 }
            if chunk.label != nil { used += ScheduleMetrics.header + ScheduleMetrics.rowGap }
            for (eventIndex, event) in chunk.events.enumerated() {
                if eventIndex > 0 { used += ScheduleMetrics.rowGap }
                used += ScheduleMetrics.eventHeight(event)
            }
        }
        return used
    }
}
