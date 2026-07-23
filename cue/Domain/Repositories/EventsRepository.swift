//
//  EventsRepository.swift
//  cue / Domain
//

import Foundation

/// iOS "캘린더" 이벤트 저장소 추상화 — Domain이 소유하는 프로토콜. 구현은 Data 계층(EventKit).
///
/// 신규 이벤트 입력은 iOS 캘린더 네이티브 `EKEventEditViewController`가 담당하므로
/// 이 프로토콜은 권한 요청과 조회만 노출한다. 수정·삭제 등은 후속 사이클에서.
protocol EventsRepository: Sendable {
    /// 캘린더 접근 권한을 요청한다 (필요 시 시스템 프롬프트). 결과 상태를 돌려준다.
    func requestAccess() async -> EventsAccess
    /// 프롬프트 없이 현재 권한 상태만 읽는다 — 앱 시작 프리페치용(`RemindersRepository`와 동일).
    func currentAccess() async -> EventsAccess
    /// `[from, to)` 범위에 걸친 이벤트를 모든 캘린더에서 모아 돌려준다.
    /// 범위와 일부라도 겹치는(straddling) 이벤트도 포함된다 — EventKit 기본 동작.
    func fetchEvents(from: Date, to: Date) async throws -> [CalendarEvent]
    /// 사용자가 등록한 모든 캘린더 목록 — 설정의 "볼 캘린더 선택" 체크리스트용.
    func fetchCalendars() async throws -> [EventCalendar]
    /// 외부에서 이벤트가 변경됐다는 신호 스트림 — 값은 싣지 않고, 구독자는 신호가 오면
    /// `fetchEvents`로 다시 가져온다. EventKit 구현은 `EKEventStoreChanged` 노티를 노출.
    /// 구독은 호출 측의 `Task`에 묶여 cancel 시 자동 종료된다.
    func changes() -> AsyncStream<Void>
}

extension EventsRepository {
    /// 기본 구현 — 프롬프트 없는 상태 조회가 없는 구현(테스트 더블 등)은 requestAccess로
    /// 폴백한다. 실 EventKit 구현은 반드시 상태-전용 조회로 오버라이드한다.
    func currentAccess() async -> EventsAccess { await requestAccess() }
}
