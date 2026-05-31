//
//  ScheduleViewModel.swift
//  cue / Presentation
//

import Foundation
import Observation

/// 일정 탭의 상태 + 동작.
///
/// 권한 요청, 신규 이벤트 시트 표시, 그리고 향후 일정 로드를 담당한다.
/// 신규 이벤트 입력 자체는 `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가
/// 처리한다 — ViewModel은 시트 표시/닫힘 상태만 관리한다.
///
/// 페이지네이션: 첫 진입에 30일(`initialDays`)을 가져오고, List 바닥의 trigger row가
/// `loadMore()`를 호출하면 그 뒤로 2주(`pageDays`)씩 이어 붙인다. 중복 fetch는
/// `isLoadingMore` 가드로 차단.
@MainActor
@Observable
final class ScheduleViewModel {
    private let requestAccessUseCase: RequestEventsAccessUseCase
    private let fetchEventsUseCase: FetchEventsUseCase
    /// 첫 진입 시 가져올 일수. 사용자 결정: 1달, 과거 미포함.
    private static let initialDays = 30
    /// 바닥 도달 시 추가로 가져올 일수. 사용자 결정: 2주.
    private static let pageDays = 14

    private(set) var access: EventsAccess = .notDetermined
    /// 날짜별로 그룹핑된 이벤트. 일정 없는 날은 생략, 날짜·시작시간 오름차순.
    private(set) var eventsByDay: [DayGroup] = []
    /// 우상단 + 버튼이 띄우는 "신규 이벤트" 시트 표시 여부.
    var showingNewEvent = false
    /// row 탭이 띄우는 "이벤트 편집" 시트. nil이면 닫힘.
    /// `Identifiable`인 `CalendarEvent`를 그대로 두면 `.sheet(item:)`이 자동 binding.
    var editingEvent: CalendarEvent?

    /// 다음 페이지의 시작점. 직전 페이지의 종료 시점과 같다.
    private var fetchedUntil: Date = Date()
    /// `loadMore()` 진행 중이면 true — trigger row가 viewport에 여러 번 들어오더라도
    /// 동시 중복 fetch를 막는다.
    private(set) var isLoadingMore = false

    init(dependencies: Dependencies) {
        self.requestAccessUseCase = dependencies.requestEventsAccess
        self.fetchEventsUseCase = dependencies.fetchEvents
    }

    /// 화면이 나타날 때 한 번 호출. 권한을 확보하고 grant 시 첫 페이지를 로드한다.
    func onAppear() async {
        access = await requestAccessUseCase()
        guard access == .granted else { return }
        await loadInitial()
    }

    /// + 버튼 액션 — 신규 이벤트 시트를 연다.
    func presentNewEvent() {
        showingNewEvent = true
    }

    /// 시트의 저장·취소 콜백에서 호출 — 시트를 닫는다.
    func dismissNewEvent() {
        showingNewEvent = false
    }

    /// 이벤트 row 탭 — 편집 시트를 연다.
    /// 구독 캘린더(공휴일 등 `isReadOnly == true`)는 EventKit이 수정을 막으므로 시트를
    /// 띄우지 않고 무시한다 — 띄워도 저장이 안 되어 사용자 혼란만 만든다.
    func presentEdit(_ event: CalendarEvent) {
        guard !event.isReadOnly else { return }
        editingEvent = event
    }

    /// 편집 시트 콜백 — 시트를 닫는다.
    func dismissEdit() {
        editingEvent = nil
    }

    /// 바닥 trigger가 viewport에 들어오면 호출 — 다음 2주를 fetch해 이어 붙인다.
    /// 권한 없거나 이미 로딩 중이면 no-op. 실패 시 `fetchedUntil`을 갱신하지 않아
    /// 다음 호출에서 같은 범위로 재시도된다.
    func loadMore() async {
        guard access == .granted, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let from = fetchedUntil
        let to = Calendar.current.date(byAdding: .day, value: Self.pageDays, to: from) ?? from
        do {
            let events = try await fetchEventsUseCase(from: from, to: to)
            eventsByDay = Self.merge(existing: eventsByDay, new: Self.groupByDay(events))
            fetchedUntil = to
        } catch {
            // fetchedUntil 유지 — 다음 호출에서 재시도.
        }
    }

    /// 첫 페이지(오늘 → +initialDays) 로드. 실패 시 빈 배열로 둔다.
    private func loadInitial() async {
        let today = Calendar.current.startOfDay(for: Date())
        let to = Calendar.current.date(
            byAdding: .day, value: Self.initialDays, to: today
        ) ?? today
        do {
            let events = try await fetchEventsUseCase(from: today, to: to)
            eventsByDay = Self.groupByDay(events)
            fetchedUntil = to
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

    /// 기존 그룹들에 새 그룹들을 병합한다. 같은 날짜의 이벤트는 합치고, id 중복은 제거,
    /// 그룹 내부는 시작 시간 오름차순, 그룹은 날짜 오름차순.
    static func merge(existing: [DayGroup], new: [DayGroup]) -> [DayGroup] {
        var byDate: [Date: [CalendarEvent]] = [:]
        for group in existing {
            byDate[group.date] = group.events
        }
        for group in new {
            byDate[group.date, default: []].append(contentsOf: group.events)
        }
        return byDate
            .map { date, events in
                var seenIDs: Set<String> = []
                let unique = events.filter { seenIDs.insert($0.id).inserted }
                return DayGroup(date: date, events: unique.sorted { $0.startDate < $1.startDate })
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
