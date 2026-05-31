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
                daySection(group)
            }
            if viewModel.access == .granted {
                loadMoreTrigger
            }
        }
        .listStyle(.plain)
        .listRowSpacing(Spacing.zero)
        // 섹션 간 gap이 있으면 rail이 그 영역에서 끊기므로 0. 헤더 자체 padding으로 호흡 확보.
        .listSectionSpacing(Spacing.zero)
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
        .sheet(item: $viewModel.editingEvent) { event in
            EventEditSheet(
                eventStore: eventStore,
                editingEventID: event.id,
                onCompletion: { viewModel.dismissEdit() }
            )
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

    /// 하루 섹션 — 헤더(날짜+요일, 토/일 색 분기) + 그날의 이벤트 row들.
    /// 헤더에도 rail 세로선이 통과하도록 같은 좌측 column을 두고, row의 inset과 헤더의
    /// inset을 일치시켜 rail이 한 줄로 이어진다. row 사이 시스템 separator(divider)는
    /// 기본값 그대로 둔다.
    @ViewBuilder
    private func daySection(_ group: DayGroup) -> some View {
        Section {
            ForEach(group.events) { event in
                EventRow(event: event)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.presentEdit(event)
                    }
                    .listRowInsets(.init(
                        top: Spacing.zero, leading: Spacing.zero,
                        bottom: Spacing.zero, trailing: Spacing.md
                    ))
            }
        } header: {
            dayHeader(group)
                .listRowInsets(.init(
                    top: Spacing.zero, leading: Spacing.zero,
                    bottom: Spacing.zero, trailing: Spacing.md
                ))
        }
    }

    /// 날짜+요일 헤더 — 좌측에 rail 통과용 세로선 column(점 없음) + 텍스트.
    /// padding을 Text에만 주고 HStack 자체엔 두지 않는다 — HStack에 padding을 걸면
    /// padding 영역엔 rail이 안 그려져 row와 row 사이 헤더 영역에서 세로선이 끊긴다.
    ///
    /// padding은 비대칭(위 md, 아래 xs) — 헤더는 자기 그룹의 첫 row와 가깝게 묶여 보이고
    /// 이전 그룹과는 여유 있게 떨어지는 게 정보 계층 측면에서 자연스럽다.
    private func dayHeader(_ group: DayGroup) -> some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            railSpine
            Text(Self.dayHeaderFormatter.string(from: group.date))
                .font(.callout.weight(.semibold))
                .foregroundStyle(Self.headerColor(for: group.date))
                .textCase(nil)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.xs)
            Spacer(minLength: Spacing.zero)
        }
        .background(Color(.systemBackground))
    }

    /// List 바닥의 페이지네이션 trigger — viewport에 들어오면 ViewModel에 다음 2주를
    /// 요청한다. 자체 시각 컨텐츠 없이 가벼운 placeholder + ProgressView(로딩 시).
    /// row 자체엔 separator도 inset도 두지 않아 사용자에겐 보이지 않는다.
    @ViewBuilder
    private var loadMoreTrigger: some View {
        HStack {
            Spacer()
            if viewModel.isLoadingMore {
                ProgressView()
                    .padding(.vertical, Spacing.md)
            } else {
                Color.clear.frame(height: 1)
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.init(
            top: Spacing.zero, leading: Spacing.zero,
            bottom: Spacing.zero, trailing: Spacing.zero
        ))
        .onAppear {
            Task { await viewModel.loadMore() }
        }
    }

    /// 헤더용 rail 세로선 — `EventRow.railColumn`과 같은 폭·동일한 가운데 정렬로
    /// 두어 row와 헤더의 rail이 정확히 한 줄로 보이게 한다(점 없음).
    /// `Color.clear` placeholder가 ZStack height를 greedy로 만들어 헤더 영역에서도
    /// rail이 끊기지 않게 한다 — Rectangle만 두면 ZStack 자연 height가 0으로 collapse.
    private var railSpine: some View {
        ZStack {
            Color.clear
                .frame(width: Spacing.lg)
                .frame(maxHeight: .infinity)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
        }
    }

    /// 섹션 헤더 — "5월 31일 토요일" 형식. ko_KR 고정.
    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 EEEE"
        return formatter
    }()

    /// 요일별 헤더 색 — 일요일 빨강, 토요일 파랑, 평일은 시스템 기본(`.primary`).
    /// `Calendar.component(.weekday:)`은 1=일, 7=토 (`Calendar.current`).
    private static func headerColor(for date: Date) -> Color {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: return .red
        case 7: return .blue
        default: return .primary
        }
    }
}

/// 한 이벤트 row — 좌측 rail(세로선+캘린더 색 점) + 캡슐 제목 + 시간.
///
/// rail은 row 전체 높이를 채워 위·아래 row와 자연스럽게 이어진다 — `.padding(.vertical)`은
/// `content`에만 주고 row 자체엔 두지 않는다. ListRowSeparator(.hidden)으로 시스템 구분선을
/// 끄면 rail이 단독으로 시각 구분 역할을 한다.
private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            railColumn
            content
        }
    }

    /// 좌측 rail = 1pt 세로선 + 가운데 캘린더 색 점(8pt). 세로선은 부모 height를 채워
    /// 인접 row의 rail과 끊김 없이 이어진다.
    ///
    /// `Color.clear`를 layout placeholder로 두지 않으면 Rectangle 단독으로는 ZStack에
    /// height를 못 알려줘 maxHeight: .infinity가 0으로 잡힌다(헤더에서 rail이 안 보이던
    /// 원인). placeholder가 부모 height greedy로 늘어나면 그 위에 Rectangle·Circle이
    /// overlay되어 정확히 그려진다.
    private var railColumn: some View {
        ZStack {
            Color.clear
                .frame(width: Spacing.lg)
                .frame(maxHeight: .infinity)
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)
            Circle()
                .fill(eventColor)
                .frame(width: Spacing.sm, height: Spacing.sm)
        }
    }

    /// row 우측 본문 — 캡슐 제목 + 우측 시간.
    /// `.padding(.vertical)`을 키우면 row 자체가 길어져 rail 점 사이 간격도 함께 늘어난다.
    private var content: some View {
        HStack(spacing: Spacing.sm) {
            titleCapsule
            Spacer(minLength: Spacing.sm)
            Text(timeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Spacing.md)
    }

    /// 캡슐 = 캘린더 색의 옅은 배경 + 캘린더 색 글씨. EventKit이 주는 raw hex 그대로
    /// 사용(외부 데이터 표현 — 디자인 시스템 컬러 규칙 예외 항목).
    private var titleCapsule: some View {
        Text(event.title)
            .font(.body.weight(.semibold))
            .foregroundStyle(eventColor)
            .lineLimit(1)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Capsule().fill(eventColor.opacity(0.18)))
    }

    /// 이벤트가 속한 캘린더 색. hex 파싱 실패면 시스템 accent로 fallback.
    private var eventColor: Color {
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
