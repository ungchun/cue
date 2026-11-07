//
//  EventEditForm.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 이벤트 상세 시트의 편집 모드 본문 — 컨테이너(EventDetailSheet)의 `Form` 안에 놓이는 섹션 묶음.
///
/// 섹션 구성은 Apple 캘린더 편집 시트 순서를 따른다: 제목·위치 / 종일·시작·종료·시간대 /
/// 반복 / 캘린더 / 알림·두 번째 알림·다음으로 표시 / URL·메모.
/// 이동 시간·초대받은 사람 편집은 EventKit이 서드파티에 열어 주지 않아 없다.
struct EventEditForm: View {
    @Binding var draft: EventEditDraft
    /// 쓰기 가능한 캘린더 목록 — 캘린더 선택 행.
    let calendars: [EKCalendar]

    @State private var showingLocationPicker = false

    var body: some View {
        Section {
            TextField("Title", text: $draft.title, axis: .vertical)
                .font(.title2.weight(.semibold))
            locationRow
        }

        Section {
            Toggle("All-day", isOn: $draft.isAllDay.animation())
            Group {
                DatePicker("Starts", selection: startBinding, displayedComponents: dateComponents)
                // 종료는 시작 이전으로 못 내린다 — 드래프트 클램프와 피커 범위 이중 방어.
                DatePicker("Ends", selection: endBinding, in: draft.start..., displayedComponents: dateComponents)
            }
            // 시간 지정 이벤트는 이벤트 시간대의 벽시계로 보여준다(Apple과 동일) — 시간대 행과 짝.
            .environment(\.timeZone, draft.isAllDay ? .current : (draft.timeZone ?? .current))
            if !draft.isAllDay {
                timeZoneRow
            }
        }

        // 반복 — 할일 시트와 공용 행(메뉴 피커 + 사용자화 요약 + 반복 종료).
        Section {
            RepeatRows(
                recurrence: $draft.recurrence,
                recurrenceEnd: $draft.recurrenceEnd,
                anchorDate: draft.start
            )
        }

        if !calendars.isEmpty {
            Section {
                calendarPicker
            }
        }

        Section {
            alarmRows(selection: $draft.firstAlarm, title: "Alert")
            // 두 번째 알림은 첫 알림이 있을 때만 — Apple과 동일.
            if draft.firstAlarm != .none {
                alarmRows(selection: $draft.secondAlarm, title: "Second Alert")
            }
            if !availabilityOptions.isEmpty {
                availabilityPicker
            }
        }

        Section {
            TextField("URL", text: $draft.urlString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Note", text: $draft.notes, axis: .vertical)
                .lineLimit(3...)
        }
    }

    // MARK: - 위치

    /// 위치 — 탭하면 위치 검색 시트(현재 위치·지도 검색). 선택되면 제목+주소 표시 + ⓧ로 제거.
    private var locationRow: some View {
        HStack {
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
                    Text("Location")
                        .foregroundStyle(Color(.placeholderText))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)

            if draft.location != nil {
                Button {
                    draft.location = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerSheet { location in
                draft.location = location
            }
        }
    }

    // MARK: - 시간

    private var dateComponents: DatePickerComponents {
        draft.isAllDay ? [.date] : [.date, .hourAndMinute]
    }

    /// 시작 바인딩 — 지속시간 유지 로직은 드래프트가 갖는다.
    private var startBinding: Binding<Date> {
        Binding(get: { draft.start }, set: { draft.setStart($0) })
    }

    private var endBinding: Binding<Date> {
        Binding(get: { draft.end }, set: { draft.setEnd($0) })
    }

    /// 시간대 — 검색 목록으로 푸시. 유동(nil) 이벤트는 기기 시간대로 표시한다.
    private var timeZoneRow: some View {
        let zone = draft.timeZone ?? .current
        return NavigationLink {
            TimeZonePickerScreen(selection: zone) { draft.setTimeZone($0) }
        } label: {
            LabeledContent("Time Zone", value: TimeZonePickerScreen.cityName(for: zone))
        }
    }

    // MARK: - 알림

    /// 알림 메뉴 + (사용자 지정일 때) 일시 피커.
    @ViewBuilder
    private func alarmRows(selection: Binding<EventEditDraft.Alarm>, title: LocalizedStringKey) -> some View {
        Picker(title, selection: selection) {
            ForEach(alarmOptions(current: selection.wrappedValue), id: \.self) { option in
                Text(option.label).tag(option)
            }
        }
        if case .absolute(let date) = selection.wrappedValue {
            DatePicker(
                "Date",
                selection: Binding(get: { date }, set: { selection.wrappedValue = .absolute($0) }),
                displayedComponents: [.date, .hourAndMinute]
            )
        }
    }

    /// 프리셋 + 사용자 지정. 사용자 지정의 tag는 현재 값 그대로(일시를 바꿔도 선택 유지),
    /// 아니면 기본값(이벤트 시작 시각). 보존 알림(custom)이 걸린 칸은 그 값을 대신 보여
    /// 같은 "사용자화" 항목이 둘 뜨지 않게 한다.
    private func alarmOptions(current: EventEditDraft.Alarm) -> [EventEditDraft.Alarm] {
        let presets = EventEditDraft.Alarm.presets(isAllDay: draft.isAllDay)
        if current == .custom { return presets + [.custom] }
        return presets + [current.isAbsolute ? current : .absolute(draft.start)]
    }

    // MARK: - 캘린더 · 다음으로 표시

    private var calendarPicker: some View {
        Picker("Calendar", selection: $draft.calendarID) {
            ForEach(calendars, id: \.calendarIdentifier) { calendar in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(Color(cgColor: calendar.cgColor))
                        .frame(width: Spacing.sm, height: Spacing.sm)
                    Text(calendar.title)
                }
                .tag(Optional(calendar.calendarIdentifier))
            }
        }
    }

    /// 선택한 캘린더가 지원하는 선택지 — 캘린더를 바꾸면 따라 바뀐다. 비면 행을 숨긴다.
    private var availabilityOptions: [EKEventAvailability] {
        guard let calendar = calendars.first(where: { $0.calendarIdentifier == draft.calendarID }) else { return [] }
        return EventEditDraft.availabilityOptions(for: calendar.supportedEventAvailabilities)
    }

    /// 다음으로 표시 — 현재 값이 선택지에 없으면(신규·캘린더 변경) 첫 선택지(바쁨)로 보인다.
    /// 저장 시 컨테이너가 선택지 밖 값을 걸러 EventKit 기본값을 유지한다.
    private var availabilityPicker: some View {
        let options = availabilityOptions
        let binding = Binding<EKEventAvailability>(
            get: { options.contains(draft.availability) ? draft.availability : options[0] },
            set: { draft.availability = $0 }
        )
        return Picker("Show As", selection: binding) {
            ForEach(options, id: \.self) { option in
                Text(EventEditDraft.label(for: option)).tag(option)
            }
        }
    }
}
