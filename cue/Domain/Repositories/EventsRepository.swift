//
//  EventsRepository.swift
//  cue / Domain
//

/// iOS "캘린더" 이벤트 저장소 추상화 — Domain이 소유하는 프로토콜. 구현은 Data 계층(EventKit).
///
/// 현재는 권한 요청만 필요하다 — 신규 이벤트 입력은 iOS 캘린더 네이티브
/// `EKEventEditViewController`가 담당한다(Presentation 계층에서 직접 띄움).
/// 이벤트 fetch·수정 등은 후속 사이클에서 추가한다.
protocol EventsRepository: Sendable {
    /// 캘린더 접근 권한을 요청한다 (필요 시 시스템 프롬프트). 결과 상태를 돌려준다.
    func requestAccess() async -> EventsAccess
}
