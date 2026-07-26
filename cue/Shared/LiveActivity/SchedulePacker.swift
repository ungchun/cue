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
                        let head = showsHeader ? ScheduleMetrics.header + ScheduleMetrics.headerGap : 0
                        inc = lead + head + ScheduleMetrics.eventHeight(event)
                    } else if let previous = chunk.last {
                        inc = ScheduleMetrics.rowGap(previous: previous, next: event)
                            + ScheduleMetrics.eventHeight(event)
                    } else {
                        inc = ScheduleMetrics.eventHeight(event)
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
/// 잘라 **총높이 ≤ 160pt가 보장**된다. xSmall 고정 + 조합별 간격 기준 컬럼당 시간 이벤트
/// 3개(헤더 포함) — 헤더 2개짜리 열도 시간 이벤트 3개까지 들어간다(레퍼런스급 밀도).
enum ScheduleMetrics {
    /// 위젯 상하 패딩 — 이 값이 바뀌면 columnMax(높이 예산)가 자동으로 따라간다.
    static let outerPadding: CGFloat = Spacing.smd      // 12
    /// 위젯 좌우 패딩 — 높이 예산과 무관.
    static let outerHorizontalPadding: CGFloat = Spacing.md    // 16
    /// 두 열 사이 간격 — HStack spacing이라 디바이더 양옆에 각각 적용된다.
    static let columnGap: CGFloat = Spacing.smd         // 12
    /// 컬럼 내 날짜 묶음 사이 간격 — 160pt 예산에 한 줄이라도 더 들어가게 조밀하게.
    static let dayGap: CGFloat = Spacing.xs             // 4
    /// 날짜 헤더 ↔ 첫 이벤트 간격.
    static let headerGap: CGFloat = Spacing.xxs         // 2
    /// 시간 일정의 제목 줄 ↔ 시간 줄 간격 — 리딩만으론 살짝 붙어 보여 미세 보정(토큰 밖 의도값).
    static let titleTimeGap: CGFloat = 1.5

    /// 인접 행 간격 — 행 종류 조합별로 다르다. 뷰(ScheduleDayView)의 행별 상단 패딩과 반드시 동기.
    /// 배경 경계가 선명할수록 넉넉히 — 캡슐끼리 6(토큰 밖 의도값) > 그 외 4.
    static func rowGap(previous: LiveEventItem, next: LiveEventItem) -> CGFloat {
        switch (previous.isAllDay, next.isAllDay) {
        case (true, true): return 6
        default: return Spacing.xs
        }
    }

    /// 줄높이는 **xSmall 콘텐츠 크기로 고정해** 읽는다 — iOS 26의 표준(.large) 타입 램프가
    /// 커져(caption1 실측 16.3, 이전 14.3) 잠금화면 예산 136pt에 행이 몇 개 못 들어간다.
    /// 뷰가 `.dynamicTypeSize(.xSmall)`로 렌더를 고정하므로, 추정도 같은 카테고리로 고정해
    /// 추정=렌더를 유지한다(어긋나면 조기 마감·잘림이 재발 — 실기기 진단 오버레이로 확정한 이력).
    private static let defaultTraits = UITraitCollection(preferredContentSizeCategory: .extraSmall)

    /// 이벤트 텍스트(제목·종일 캡슐) 크기 — 시스템 크기 설정과 무관하게 밀도를
    /// 보장하려는 디자인 결정으로 고정 크기를 쓴다. 뷰(ScheduleEventRow)와 동기.
    static let eventFontSize: CGFloat = 12.5
    /// 시간 줄은 제목보다 살짝 작게(12.5/12) — 크기로도 위계를 준다. 뷰와 동기.
    static let timeFontSize: CGFloat = 12

    /// 이벤트 한 줄의 줄높이 — 고정 크기 `.system(size:)` 텍스트의 실렌더는 `systemFont(ofSize:)`
    /// lineHeight와 일치한다(실기기 실측 2026-07: 12.5pt 행 30.9 = 14.9+1.5+14.3 + 한글 캐스케이드 ~0.1).
    /// 이전엔 caption2 **스타일** 메트릭(리딩 포함 15.1)을 크기 비로 스케일해 행당 ~4.3pt 과대
    /// → 들어갈 날짜를 통째로 버렸다. 스타일 줄높이는 스타일로 렌더하는 헤더에만 쓴다.
    static var titleLine: CGFloat { UIFont.systemFont(ofSize: eventFontSize).lineHeight }
    static var timeLine: CGFloat { UIFont.systemFont(ofSize: timeFontSize).lineHeight }

    /// 행당 안전 마진 — 실기기 실측(2026-07) 시간행은 30.95~31.2로 흔들린다(한글 캐스케이드
    /// ~0.2 + 3x 렌더 양자화 1/3pt). 추정은 31.13: 참값(~31.0)을 덮고, 양자화 극단(31.2)과의
    /// 잔차 0.07은 서브픽셀이라 무시한다. 더 키우면 레퍼런스형 배치(한 열에 헤더 2 + 시간행 3,
    /// 행당 상한 31.27)가 깨져 날짜를 다시 버리게 된다 — 이 창(≤31.27)이 한글·라틴 상한이다.
    private static var rowSafetyMargin: CGFloat {
        rowSafetyMargin(languageCode: Locale.current.language.languageCode?.identifier)
    }

    /// 언어별 마진 — 톨 스크립트(태국어·데바나가리·아랍어·베트남어)는 글리프 캐스케이드가
    /// 라틴 lineHeight보다 수 pt 커서 0.4로는 하단 잘림 위험이 있다. 여유 2.0을 주는 대신
    /// 경계 케이스에서 행이 하나 덜 들어갈 수 있다(잘림보다 덜 나쁨). 실측으로 재조정 여지.
    /// 한계(의도된 트레이드오프): 기준이 **UI 언어**라 한국어 UI에 태국어 제목이 섞이면
    /// 여전히 0.4가 걸린다 — 제목 스크립트별 판정은 비용 대비 과해서 하지 않는다.
    static func rowSafetyMargin(languageCode: String?) -> CGFloat {
        ["th", "hi", "ar", "vi"].contains(languageCode ?? "") ? 2.0 : 0.4
    }

    /// 날짜 헤더는 caption2(11pt) 텍스트 스타일 그대로 렌더 — 뷰(ScheduleDayView)와 동기.
    static var header: CGFloat { caption2Line }

    private static var caption2Line: CGFloat {
        UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: defaultTraits).lineHeight
    }
    static func eventHeight(_ event: LiveEventItem) -> CGFloat {
        // 실측 대조(2026-07): 종일 19.1 / 시간행 30.9 — 아래 식 + 마진이 각각 19.2 / 31.0.
        let base = event.isAllDay
            ? titleLine + Spacing.xxs * 2               // 캡슐 상하 패딩(2) — 뷰(ScheduleEventRow)와 동기
            : titleLine + titleTimeGap + timeLine       // 제목 + 간격(titleTimeGap) + 시간 — 뷰와 동기
        return base + rowSafetyMargin
    }

    /// 160pt(시스템 최대) − 상하 패딩.
    static var columnMax: CGFloat { 160 - outerPadding * 2 }
}
