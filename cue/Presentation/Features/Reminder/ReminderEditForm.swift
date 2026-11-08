//
//  ReminderEditForm.swift
//  cue / Presentation
//

import SwiftUI

/// 할일 세부사항 시트의 편집 모드 본문 — 컨테이너(ReminderDetailSheet)의 `Form` 안에 놓이는 섹션 묶음.
///
/// 섹션 순서는 Apple 미리 알림 세부사항을 따른다: 제목·메모 / 날짜·시간 / 반복 / 위치 / 목록 / 우선순위.
/// 위치·우선순위는 기존 항목 수정에서만 보인다(`showsAttributes`) — 생성 경로가 받지 않는 값.
/// 목록은 선택지(`lists`)가 있으면 보인다 — 일정 탭 + 시트의 생성은 목록을 고른다.
///
/// 날짜·시간 인라인 피커는 **한 번에 하나만** 펼친다 (iOS 미리 알림과 동일).
/// 토글이 켜진 행을 다시 탭하면 펼침/접힘이 바뀐다.
struct ReminderEditForm: View {
    @Binding var draft: ReminderEditDraft
    /// 옮길 수 있는 목록 — 비면 목록 행을 숨긴다.
    let lists: [ReminderList]
    let showsAttributes: Bool

    @State private var expanded: PickerKind? = nil
    @State private var pressedKind: PickerKind? = nil
    @State private var showingLocationPicker = false

    /// 어떤 인라인 피커가 펼쳐졌는지 — 둘 다 켜져도 동시에 펼치진 않는다.
    private enum PickerKind { case date, time }

    /// 라벨 영역의 press 상태를 외부 `@State`로 흘려보낸다 — 셀 전체 하이라이트에 쓰인다.
    /// (배경은 여기서 칠하지 않고 행의 `listRowBackground`가 칠한다.)
    private struct RowPressReporter: ButtonStyle {
        let kind: PickerKind
        @Binding var pressed: PickerKind?

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onChange(of: configuration.isPressed) { _, isPressed in
                    pressed = isPressed ? kind : nil
                }
        }
    }

    var body: some View {
        Section {
            // 시트 안엔 leading 아이콘이 없어 axis: .vertical TextField 정렬 이슈가 없음.
            // Enter는 줄바꿈으로 두고, commit은 툴바 ✓ 버튼으로 명시.
            TextField("Title", text: $draft.title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            TextField("Note", text: $draft.notes, axis: .vertical)
                .font(.body)
                .foregroundStyle(.primary)
        }

        Section("Date & Time") {
            toggleRow(
                kind: .date,
                label: "Date",
                systemImage: "calendar",
                isOn: draft.hasDate,
                subtitle: draft.hasDate ? dateSubtitle : nil,
                binding: dateBinding
            )
            if expanded == .date {
                DatePicker("", selection: $draft.dueDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .listRowInsets(EdgeInsets(
                        top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md
                    ))
            }

            toggleRow(
                kind: .time,
                label: "Time",
                systemImage: "clock",
                isOn: draft.hasTime,
                subtitle: draft.hasTime ? timeSubtitle : nil,
                binding: timeBinding
            )
            if expanded == .time {
                HStack {
                    Spacer()
                    DatePicker("", selection: $draft.dueDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    Spacer()
                }
                .listRowInsets(EdgeInsets())
            }
        }

        // 반복 — 날짜가 켜져 있을 때만(Apple 미리 알림과 동일). 반복 종료는
        // 반복이 실제로 설정됐을 때만 RepeatRows가 노출한다.
        if draft.hasDate {
            Section {
                RepeatRows(
                    recurrence: $draft.recurrence,
                    recurrenceEnd: $draft.recurrenceEnd,
                    anchorDate: draft.dueDate
                )
            }
        }

        if showsAttributes {
            locationSection
        }
        if !lists.isEmpty {
            Section {
                listPicker
            }
        }
        if showsAttributes {
            Section {
                Picker("Priority", selection: $draft.priority) {
                    ForEach(ReminderPriority.allCases, id: \.self) { priority in
                        Text(priority.label).tag(priority)
                    }
                }
            }
        }
    }

    // MARK: - 날짜 · 시간

    /// 날짜·시간 공통 토글 행 — 아이콘 + 라벨(+서브타이틀) + 트레일링 토글.
    /// 토글이 켜진 상태에서 라벨 영역을 탭하면 해당 피커의 펼침이 토글된다.
    private func toggleRow(
        kind: PickerKind,
        label: LocalizedStringKey,
        systemImage: String,
        isOn: Bool,
        subtitle: String?,
        binding: Binding<Bool>
    ) -> some View {
        HStack {
            Button {
                if isOn { toggleExpanded(kind) }
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: systemImage)
                        .foregroundStyle(
                            expanded == kind ? Color.accentColor : Color.secondary
                        )
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(label)
                            .foregroundStyle(.primary)
                        if let subtitle {
                            // 서브타이틀은 iOS 미리알림과 동일하게 캡션 크기 — 라벨보다 확연히 작게.
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                // 라벨 + 토글 사이 빈 공간까지 탭으로 인식시키려고 너비를 가능한 만큼 확장.
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowPressReporter(kind: kind, pressed: $pressedKind))

            Toggle("", isOn: binding)
                .labelsHidden()
                // 앱 전역 무채색 tint가 다크 모드에서 ON 트랙을 흰색으로 만든다 — 시스템 표준(초록)으로.
                .tint(.green)
        }
        // 셀 전체에 호버 느낌 — `listRowBackground`는 행 바닥 전체(좌우 끝까지) 채운다.
        // 단, 안 눌렸을 때는 `nil`을 넘겨야 시스템 그룹 박스 배경이 유지된다.
        .listRowBackground(pressHighlight(for: kind))
    }

    /// 누른 행만 강조 색을 돌려주고, 그 외엔 `nil`로 기본 행 배경을 유지한다.
    private func pressHighlight(for kind: PickerKind) -> Color? {
        pressedKind == kind ? Color.primary.opacity(0.08) : nil
    }

    /// 날짜 토글 — 켜면 날짜 피커를 펼치고, 끄면 시간도 같이 꺼진다 (시간은 날짜 없이 못 산다).
    private var dateBinding: Binding<Bool> {
        Binding(
            get: { draft.hasDate },
            set: { isOn in
                withAnimation {
                    draft.hasDate = isOn
                    if isOn {
                        expanded = .date
                    } else {
                        draft.hasTime = false
                        expanded = nil
                    }
                }
            }
        )
    }

    /// 시간 토글 — 켜면 날짜도 자동으로 켜지고 시간 피커가 펼쳐진다.
    /// 끄면 그냥 접힌다 — 날짜 피커를 자동으로 다시 펼치진 않는다.
    private var timeBinding: Binding<Bool> {
        Binding(
            get: { draft.hasTime },
            set: { isOn in
                withAnimation {
                    draft.hasTime = isOn
                    if isOn {
                        draft.hasDate = true
                        expanded = .time
                    } else {
                        expanded = nil
                    }
                }
            }
        )
    }

    /// 같은 행을 다시 탭하면 펼침을 닫고, 다른 행이면 그쪽으로 옮긴다.
    private func toggleExpanded(_ kind: PickerKind) {
        withAnimation {
            expanded = (expanded == kind) ? nil : kind
        }
    }

    /// "오늘" / "내일" / "5월 24일" — 마감일 행 서브타이틀.
    private var dateSubtitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(draft.dueDate) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(draft.dueDate) { return String(localized: "Tomorrow") }
        return draft.dueDate.formatted(.dateTime.month().day())
    }

    /// "오전 11:00" / "오후 9:30" — 시간 행 서브타이틀.
    private var timeSubtitle: String {
        draft.dueDate.formatted(.dateTime.hour().minute())
    }

    // MARK: - 위치

    /// 위치 알림 — 토글을 켜면 장소 행(위치 검색 시트)과 도착/출발 세그먼트가 나온다.
    private var locationSection: some View {
        Section {
            Toggle(isOn: $draft.isLocationEnabled.animation()) {
                Label("Location", systemImage: "location")
            }
            .tint(.green)
            if draft.isLocationEnabled {
                Button {
                    showingLocationPicker = true
                } label: {
                    if let location = draft.location {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(location.title)
                                .foregroundStyle(.primary)
                            if let address = location.address {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    } else {
                        Text("Enter Location")
                            .foregroundStyle(Color(.placeholderText))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                // 시트는 **이 행에** 붙인다. Section에 붙이면 행마다(토글·장소·세그먼트) 적용돼
                // 같은 바인딩으로 시트가 여러 번 뜨려다 상세 시트까지 닫힌다(실측: 위치 입력 탭 → 시트 전부 닫힘).
                .sheet(isPresented: $showingLocationPicker) {
                    // 위치 알림은 좌표가 있어야 울린다 — 이름만 입력하는 행은 숨기고, 좌표 해석에
                    // 실패한 선택은 드래프트가 거절한다.
                    LocationPickerSheet(onSelect: { location in
                        draft.selectLocation(location)
                    }, requiresCoordinate: true)
                }

                Picker("Location", selection: $draft.proximity) {
                    Text(ReminderLocationAlarm.Proximity.arriving.label).tag(ReminderLocationAlarm.Proximity.arriving)
                    Text(ReminderLocationAlarm.Proximity.leaving.label).tag(ReminderLocationAlarm.Proximity.leaving)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    // MARK: - 목록

    private var listPicker: some View {
        Picker("List", selection: $draft.listID) {
            ForEach(lists) { list in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(list.colorHex.flatMap(Color.init(hex:)) ?? .secondary)
                        .frame(width: Spacing.sm, height: Spacing.sm)
                    Text(list.title)
                }
                .tag(list.id)
            }
        }
    }
}
