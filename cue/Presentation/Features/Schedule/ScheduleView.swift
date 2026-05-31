//
//  ScheduleView.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 일정 탭 화면 — "타임라인" 헤더 + 우상단 신규 이벤트 + 버튼 + 향후 30일치 이벤트 리스트.
///
/// 이벤트는 일정 있는 날만 섹션으로 묶여 표시된다(`DayGroup` 단위). 신규 입력은
/// `EKEventEditViewController`(iOS 캘린더 네이티브 시트)가 처리한다.
///
/// `eventStore`는 화면 진입 시 한 번 만들어 warm-up하고 `EventEditSheet`에 그대로
/// 주입한다 — 시트 안에서 새 store를 만들면 캘린더 목록·기본 캘린더 조회가 시트 표시
/// 시점에 처음 일어나 데이터가 한 박자 늦게 채워지고 시스템 로그가 무더기로 찍힌다.
struct ScheduleView: View {
    @Bindable var viewModel: ScheduleViewModel
    /// 신규 이벤트 시트와 공유하는 EKEventStore. `@State`로 view 생애 동안 유지한다.
    @State private var eventStore = EKEventStore()

    // 좌상단 "캘린더" 버튼 — Apple Calendar 앱 호출용 SwiftUI 환경 핸들.
    // ReminderView의 "미리 알림" 버튼과 동일 패턴.
    @Environment(\.openURL) private var openURL

    var body: some View {
        // ReminderView와 동일한 패턴: navigation bar는 inline 모드로 두고 large title은
        // List 첫 row에 직접 박는다. List가 가진 자체 top inset 덕에 toolbar↔title 간격이
        // 자연스럽게 맞고, 두 탭의 헤더 라인이 일치한다.
        List {
            Text("타임라인")
                .font(.largeTitle.bold())
                .listRowSeparator(.hidden)

            ForEach(viewModel.eventsByDay) { group in
                Section {
                    ForEach(group.events) { event in
                        EventRow(event: event)
                    }
                } header: {
                    Text(Self.dayHeaderFormatter.string(from: group.date))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .listRowSpacing(Spacing.zero)
        .listSectionSpacing(Spacing.md)
        .environment(\.defaultMinListRowHeight, Spacing.zero)
        .overlay { emptyOverlay }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                openCalendarAppButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.presentNewEvent()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("새 일정")
            }
        }
        .task {
            await viewModel.onAppear()
            warmUpEventStore()
        }
        .sheet(isPresented: $viewModel.showingNewEvent) {
            EventEditSheet(eventStore: eventStore, onCompletion: {
                viewModel.dismissNewEvent()
            })
        }
    }

    /// 좌상단 "캘린더" 버튼 — Apple 캘린더 앱을 연다. `calshow://`는 캘린더 앱의 표준
    /// URL scheme. ReminderView의 `openRemindersAppButton`과 동일 패턴.
    private var openCalendarAppButton: some View {
        Button {
            if let url = URL(string: "calshow://") {
                openURL(url)
            }
        } label: {
            Text("캘린더")
        }
    }

    /// 권한이 허용된 직후 `eventStore`의 캘린더 목록·기본 캘린더 캐시를 미리 채워둔다.
    /// 첫 호출은 EventKit이 시스템 캘린더 DB·플러그인·persona 서비스에 접근하는 비용이
    /// 있어 시트 표시 시점으로 미루면 데이터 지연·시스템 로그가 사용자에게 노출된다.
    /// 화면 진입 직후 한 번 끌어두면 그 비용이 사전 분산된다.
    private func warmUpEventStore() {
        guard viewModel.access == .granted else { return }
        _ = eventStore.calendars(for: .event)
        _ = eventStore.defaultCalendarForNewEvents
    }

    /// 권한 없음 / 빈 타임라인일 때 List 위에 띄우는 안내. 이벤트가 한 건이라도 있으면
    /// 안내는 가려지고 List 본 row만 보인다.
    @ViewBuilder
    private var emptyOverlay: some View {
        switch viewModel.access {
        case .notDetermined, .denied:
            ContentUnavailableView(
                "캘린더 접근이 필요해요",
                systemImage: "calendar.badge.exclamationmark",
                description: Text("설정 → cue 에서 캘린더 권한을 켜 주세요.")
            )
        case .granted:
            if viewModel.eventsByDay.isEmpty {
                ContentUnavailableView(
                    "일정이 비어있어요",
                    systemImage: "calendar",
                    description: Text("우측 상단 +로 새 일정을 추가하세요.")
                )
            }
        }
    }

    /// 섹션 헤더 — "5월 31일 토요일" 형식. ko_KR 고정.
    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()
}

/// 한 이벤트 row — 캘린더 색 점 + 제목 + 시작-종료 시간(또는 "종일").
private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(dotColor)
                .frame(width: Spacing.sm, height: Spacing.sm)
            Text(event.title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: Spacing.md)
            Text(timeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.xs)
    }

    /// "#RRGGBB"를 SwiftUI Color로. 없으면 시스템 tint.
    private var dotColor: Color {
        guard let hex = event.calendarColorHex,
              let parsed = Color(hex: hex) else { return .accentColor }
        return parsed
    }

    /// 종일은 "종일", 아니면 "오전 9:00 - 오전 10:00" 형식 (ko_KR).
    private var timeText: String {
        if event.isAllDay { return "종일" }
        let formatter = Self.timeFormatter
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}


#Preview {
    NavigationStack {
        ScheduleView(viewModel: ScheduleViewModel(dependencies: .preview))
    }
}
