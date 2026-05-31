//
//  ScheduleViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭의 상태 + 동작.
///
/// 권한 요청, 신규 이벤트 시트 표시, 그리고 향후 30일치 이벤트 로드를 담당한다.
/// 신규 이벤트 입력 자체는 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가
/// 처리한다 — ViewModel은 시트 표시/닫힘 상태만 관리한다.
@MainActor
@Observable
final class ScheduleViewModel {
    private let requestAccessUseCase: RequestEventsAccessUseCase
    private let fetchEventsUseCase: FetchEventsUseCase
    /// 한 번에 가져올 기간(일). 오늘 0시 → +30일 24시. 사용자 결정: 1달, 과거 미포함.
    private static let lookaheadDays = 30

    private(set) var access: EventsAccess = .notDetermined
    /// 날짜별로 그룹핑된 이벤트. 일정 없는 날은 생략, 날짜·시작시간 오름차순.
    private(set) var eventsByDay: [DayGroup] = []
    /// 우상단 + 버튼이 띄우는 "신규 이벤트" 시트 표시 여부.
    var showingNewEvent = false

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestEventsAccess
        self.fetchEventsUseCase = dependencies.fetchEvents
    }

    /// 화면이 나타날 때 한 번 호출. 권한을 확보하고 grant 시 이벤트를 로드한다.
    func onAppear() async {
        access = await requestAccessUseCase()
        guard access == .granted else { return }
        await loadEvents()
    }

    /// + 버튼 액션 — 신규 이벤트 시트를 연다.
    func presentNewEvent() {
        showingNewEvent = true
    }

    /// 시트의 저장·취소 콜백에서 호출 — 시트를 닫는다.
    func dismissNewEvent() {
        showingNewEvent = false
    }

    /// 오늘 0시 → +30일 24시 범위의 이벤트를 가져와 날짜별로 그룹핑한다.
    /// 실패 시 조용히 빈 그룹 유지 — 일정 탭은 결과 없음과 오류를 시각적으로 같게 본다.
    private func loadEvents() async {
        let today = Calendar.current.startOfDay(for: Date())
        let to = Calendar.current.date(
            byAdding: .day, value: Self.lookaheadDays, to: today
        ) ?? today
        do {
            let events = try await fetchEventsUseCase(from: today, to: to)
            eventsByDay = Self.groupByDay(events)
        } catch {
            eventsByDay = []
        }
    }

    /// 이벤트들을 시작일의 캘린더 자정으로 묶고, 그룹은 날짜 오름차순, 그룹 내부는
    /// 시작 시간 오름차순으로 정렬한다.
    static func groupByDay(_ events: [CalendarEvent]) -> [DayGroup] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return buckets
            .map { date, events in
                DayGroup(date: date, events: events.sorted { $0.startDate < $1.startDate })
            }
            .sorted { $0.date < $1.date }
    }
}

/// 타임라인 한 섹션 — 한 날짜와 그날의 이벤트들.
struct DayGroup: Identifiable, Equatable, Sendable {
    /// 그날의 캘린더 자정 (`Calendar.startOfDay`)
    let date: Date
    let events: [CalendarEvent]

    var id: Date { date }
}
