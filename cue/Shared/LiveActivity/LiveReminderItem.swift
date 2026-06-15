//
//  LiveReminderItem.swift
//  cue / Domain
//

import Foundation

/// 라이브 액티비티에 표시할 미리알림 한 줄 — Domain의 `Reminder`를 줄인 스냅샷 DTO.
///
/// ContentState로 직렬화되므로 표시에 꼭 필요한 필드만 둔다(JSON ~4KB 한도 +
/// `ActivityAttributes` 시작 후 불변 정책 회피). 도메인 `Reminder` 가 진화해도 이 DTO
/// 스키마는 위젯 schema migration 안전성을 위해 신중하게 — **필드 제거 금지, 추가만**.
struct LiveReminderItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    /// 이 항목이 속한 미리알림 리스트의 색(`"#RRGGBB"`). 위젯이 체크박스 동그라미 stroke에
    /// 사용한다. `nil`이면 위젯에서 시스템 색으로 폴백 — EventKit 리스트 색(외부 데이터)이라
    /// 디자인 시스템 hex 금지의 예외다.
    let colorHex: String?
}
