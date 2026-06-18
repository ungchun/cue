//
//  LiveEventItem.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티에 표시할 캘린더 이벤트 한 건 — Domain `CalendarEvent`의 표시용 스냅샷.
///
/// `startDate`·`endDate`는 시스템 Live Activity의 `Text(_:style: .relative)` /
/// `Text(timerInterval:)`이 매 프레임 자동 갱신해주므로 그대로 들고 가면 매초 update가
/// 필요 없다. `calendarColorHex`는 EventKit이 주는 raw hex를 그대로 — 디자인 시스템
/// 컬러 규칙의 **외부 데이터 표현 예외** 항목이라 hex 통과를 허용한다.
struct LiveEventItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    /// 게시 시점에 그 행이 속한 날(day group) 기준으로 미리 계산한 시간 문구
    /// ("하루 종일" / "오전 9:00 - 오전 10:00" / "오전 6:00 →" / "→ 오전 8:00" / "진행 중").
    /// 위젯은 day별 날짜를 모르므로 use case가 `ScheduleTimeText`로 구워 넣는다.
    let timeText: String
    let calendarColorHex: String?
    /// 종일 이벤트 여부. 위젯이 종일이면 색 캡슐로 제목만, 아니면 좌측 색 막대 + 제목 +
    /// 시간(시작—끝)으로 그린다.
    ///
    /// 비옵셔널이라 합성 Decodable은 이 키를 필수로 요구한다(누락 시 기본값 안 됨). LA의
    /// ContentState는 매 게시마다 새로 만들어지는 transient 스냅샷이고 영속 마이그레이션이
    /// 없으므로 안전하다 — 구버전 LA가 떠 있다면 앱이 다음 활동에서 재게시한다.
    let isAllDay: Bool
}
