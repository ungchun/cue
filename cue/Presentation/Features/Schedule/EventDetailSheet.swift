//
//  EventDetailSheet.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 자체 이벤트 편집 시트 — Apple 캘린더의 신규/편집 시트를 SwiftUI로 재구성한다.
///
/// `EKEventEditViewController`를 쓰지 않는 이유: iOS 17부터 그 화면은 별도 시스템
/// 프로세스(OOP 원격 뷰)로 렌더돼 폼 위 터치가 우리 앱에 오지 않고, 그래서 시트를
/// 아래로 끌어 닫는 제스처가 서드파티 앱에선 동작하지 않는다(실기기 로그로 확정).
/// 자체 폼이면 일반 SwiftUI 시트라 스와이프 닫기·디자인 통일·즉시 표시가 전부 해결된다.
///
/// 기능 패리티: 제목·위치·종일·시작/종료·반복(프리셋)·알림(프리셋)·캘린더·URL·메모·삭제.
/// EventKit이 서드파티에 공개하지 않는 초대받은 사람·이동 시간은 제외. 프리셋 밖의
/// 반복·알림은 "사용자 설정"으로 표시만 하고 저장 시 보존한다(EventEditDraft 계약).
///
/// 반복 이벤트의 저장·삭제는 Apple과 동일하게 "이 이벤트에만 / 이후 모든 이벤트에"를
/// 묻는다. 저장/삭제/취소 결과는 `onCompletion`으로 전달 — 호출처 로직은 기존
/// 시스템 시트 때와 동일하다(EventEditOutcome).
struct EventDetailSheet: View {
    let eventStore: EKEventStore
    /// nil이면 신규 모드. 값이 있으면 그 ID의 기존 이벤트를 편집한다.
    let editingEventID: String?
    let onCompletion: (EventEditOutcome) -> Void

    @State private var draft: EventEditDraft
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveSpanDialog = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    /// 변경 감지용 초기 스냅샷 — X 누를 때 폐기 확인 여부.
    private let initialDraft: EventEditDraft
    /// 편집 모드의 대상 이벤트 — 저장 시점에 draft를 반영한다(그 전엔 안 건드림).
    private let editingEvent: EKEvent?
    /// 쓰기 가능한 캘린더 목록 — 캘린더 선택 행.
    private let calendars: [EKCalendar]

    init(eventStore: EKEventStore, editingEventID: String? = nil, onCompletion: @escaping (EventEditOutcome) -> Void) {
        self.eventStore = eventStore
        self.editingEventID = editingEventID
        self.onCompletion = onCompletion

        let event = editingEventID.flatMap { eventStore.event(withIdentifier: $0) }
        self.editingEvent = event
        var initial = event.map(EventEditDraft.init(event:)) ?? .newEvent(now: .now)
        if initial.calendarID == nil {
            initial.calendarID = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        }
        self.initialDraft = initial
        _draft = State(initialValue: initial)
        self.calendars = eventStore.calendars(for: .event).filter(\.allowsContentModifications)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                    TextField("Location", text: $draft.location)
                }

                Section {
                    Toggle("All-day", isOn: $draft.isAllDay.animation())
                    DatePicker("Starts", selection: startBinding, displayedComponents: dateComponents)
                    // 종료는 시작 이전으로 못 내린다 — 드래프트 클램프와 피커 범위 이중 방어.
                    DatePicker("Ends", selection: endBinding, in: draft.start..., displayedComponents: dateComponents)
                    recurrencePicker
                    alarmPicker
                }

                if !calendars.isEmpty {
                    Section {
                        calendarPicker
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

                if editingEvent != nil {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Event")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(editingEvent == nil ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if draft != initialDraft {
                            showingDiscardConfirmation = true
                        } else {
                            cancel()
                        }
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                    .popover(isPresented: $showingDiscardConfirmation) {
                        discardPopover
                            .presentationCompactAdaptation(.popover)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveTapped()
                    } label: {
                        Label("Save", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .keyboardDismissToolbar()
            // 반복 이벤트 저장 범위 — Apple 캘린더와 동일한 질문.
            .confirmationDialog("This is a repeating event.", isPresented: $showingSaveSpanDialog, titleVisibility: .visible) {
                Button("Save for This Event Only") { save(span: .thisEvent) }
                Button("Save for Future Events") { save(span: .futureEvents) }
            }
            // 삭제 — 반복이면 범위까지 묻는다.
            .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                if editingEvent?.hasRecurrenceRules == true {
                    Button("Delete This Event Only", role: .destructive) { delete(span: .thisEvent) }
                    Button("Delete All Future Events", role: .destructive) { delete(span: .futureEvents) }
                } else {
                    Button("Delete Event", role: .destructive) { delete(span: .thisEvent) }
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 행 구성

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

    /// 반복 — 프리셋 + 사용자 설정(빈도·간격·요일 등) + 반복 종료가 있는 전용 화면으로 진입.
    private var recurrencePicker: some View {
        NavigationLink {
            RepeatOptionScreen(
                recurrence: $draft.recurrence,
                recurrenceEnd: $draft.recurrenceEnd,
                eventStart: draft.start
            )
        } label: {
            HStack {
                Text("Repeat")
                Spacer()
                Text(label(for: draft.recurrence))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var alarmPicker: some View {
        Picker("Alert", selection: $draft.alarm) {
            ForEach(alarmOptions, id: \.self) { option in
                Text(label(for: option)).tag(option)
            }
        }
    }

    private var alarmOptions: [EventEditDraft.Alarm] {
        draft.alarm == .custom
            ? EventEditDraft.Alarm.presets + [.custom]
            : EventEditDraft.Alarm.presets
    }

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

    // MARK: - 라벨

    private func label(for option: EventEditDraft.Recurrence) -> String {
        switch option {
        case .none: String(localized: "Never")
        case .daily: String(localized: "Every Day")
        case .weekly: String(localized: "Every Week")
        case .biweekly: String(localized: "Every 2 Weeks")
        case .monthly: String(localized: "Every Month")
        case .yearly: String(localized: "Every Year")
        case .custom, .foreign: String(localized: "Custom")
        }
    }

    private func label(for option: EventEditDraft.Alarm) -> String {
        switch option {
        case .none: return String(localized: "None")
        case .atTime: return String(localized: "At time of event")
        case .custom: return String(localized: "Custom")
        case .minutesBefore(let minutes):
            if minutes < 60 { return String(localized: "\(minutes) minutes before") }
            if minutes == 60 { return String(localized: "1 hour before") }
            if minutes < 1_440 { return String(localized: "\(minutes / 60) hours before") }
            if minutes == 1_440 { return String(localized: "1 day before") }
            if minutes < 10_080 { return String(localized: "\(minutes / 1_440) days before") }
            return String(localized: "1 week before")
        }
    }

    /// X 버튼 popover — ReminderDetailSheet와 동일 관용구.
    private var discardPopover: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Discard Changes?")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(role: .destructive) {
                showingDiscardConfirmation = false
                cancel()
            } label: {
                Text("Discard Changes")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .frame(minWidth: 240)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    // MARK: - 액션

    private func saveTapped() {
        // 반복 시리즈의 일부면 저장 범위를 먼저 묻는다 — 그 전엔 이벤트를 안 건드린다.
        if editingEvent?.hasRecurrenceRules == true {
            showingSaveSpanDialog = true
        } else {
            save(span: .thisEvent)
        }
    }

    private func save(span: EKSpan) {
        let event = editingEvent ?? EKEvent(eventStore: eventStore)
        draft.apply(to: event)
        event.calendar = calendars.first { $0.calendarIdentifier == draft.calendarID }
            ?? event.calendar
            ?? eventStore.defaultCalendarForNewEvents
        do {
            try eventStore.save(event, span: span, commit: true)
            onCompletion(.saved)
            dismiss()
        } catch {
            eventStore.reset()   // 실패 시 캐시에 남은 미커밋 변경을 원복
            errorMessage = String(localized: "Couldn't save the event.")
        }
    }

    private func delete(span: EKSpan) {
        guard let event = editingEvent else { return }
        do {
            try eventStore.remove(event, span: span, commit: true)
            onCompletion(.deleted)
            dismiss()
        } catch {
            errorMessage = String(localized: "Couldn't delete the event.")
        }
    }

    private func cancel() {
        onCompletion(.canceled)
        dismiss()
    }
}
