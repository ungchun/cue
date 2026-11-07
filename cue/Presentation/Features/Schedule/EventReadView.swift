//
//  EventReadView.swift
//  cue / Presentation
//

import EventKit
import SwiftUI

/// 이벤트 상세 시트의 보기 모드 본문 — 컨테이너(EventDetailSheet)의 `Form` 안에 놓이는 읽기 전용 섹션.
///
/// 표시 문구는 편집 폼과 같은 드래프트 매핑(`draft`)을 쓰고, 드래프트에 없는 것(캘린더 색·
/// 초대받은 사람)만 `event`에서 읽는다. 값이 없는 행은 숨긴다. 시각은 타임라인과 같은
/// 기기 시간대로 보여주고, 이벤트 시간대가 다르면 그 시간대의 시각과 이름을 한 줄 덧붙인다.
struct EventReadView: View {
    let event: EKEvent
    /// 이벤트 스냅샷 — 시트를 연 시점 값(보기 모드에선 저장 전이라 바뀌지 않는다).
    let draft: EventEditDraft

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(draft.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                if let location = draft.location {
                    Text(location.title)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    if let address = location.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .textSelection(.enabled)
            dateBlock
            if draft.recurrence != .none {
                LabeledContent("Repeat", value: repeatText)
                if case .onDate(let date) = draft.recurrenceEnd, draft.recurrence != .foreign {
                    LabeledContent("End Repeat", value: date.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }

        if let calendar = event.calendar {
            Section {
                LabeledContent("Calendar") {
                    HStack(spacing: Spacing.sm) {
                        Circle()
                            .fill(Color(cgColor: calendar.cgColor))
                            .frame(width: Spacing.sm, height: Spacing.sm)
                        Text(calendar.title)
                    }
                }
                if showsAvailability(calendar) {
                    LabeledContent("Show As", value: EventEditDraft.label(for: draft.availability))
                }
            }
        }

        if draft.firstAlarm != .none {
            Section {
                LabeledContent("Alert", value: alarmText(draft.firstAlarm))
                if draft.secondAlarm != .none {
                    LabeledContent("Second Alert", value: alarmText(draft.secondAlarm))
                }
            }
        }

        if let attendees = event.attendees, !attendees.isEmpty {
            Section("Invitees") {
                ForEach(Array(attendees.enumerated()), id: \.offset) { _, participant in
                    participantRow(participant)
                }
            }
        }

        if url != nil || !draft.notes.isEmpty {
            Section {
                if let url {
                    LabeledContent("URL") {
                        Link(url.absoluteString, destination: url)
                            .lineLimit(1)
                    }
                }
                if !draft.notes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Note")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(draft.notes)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - 일시

    /// 하루짜리는 "날짜 / 시작–종료" 두 줄, 여러 날에 걸치면 시작·종료 행.
    @ViewBuilder
    private var dateBlock: some View {
        let calendar = Calendar.current
        // 종일 이벤트의 종료는 마지막 날 23:59:59 — 같은 날 판정에 그대로 쓸 수 있다.
        if calendar.isDate(draft.start, inSameDayAs: draft.end) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(draft.start.formatted(date: .complete, time: .omitted))
                    .foregroundStyle(.primary)
                if !draft.isAllDay {
                    Text(timeRange(in: .current))
                        .foregroundStyle(.secondary)
                }
                foreignZoneLine
            }
        } else {
            LabeledContent("Starts", value: dateText(draft.start))
            LabeledContent("Ends", value: dateText(draft.end))
            foreignZoneLine
        }
    }

    /// 이벤트 시간대가 기기와 다를 때만 — "10:00 – 11:00 · 미 동부 표준시".
    @ViewBuilder
    private var foreignZoneLine: some View {
        if !draft.isAllDay, let zone = draft.timeZone, zone.identifier != TimeZone.current.identifier {
            Text(verbatim: "\(timeRange(in: zone)) · \(TimeZonePickerScreen.zoneName(for: zone))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func dateText(_ date: Date) -> String {
        draft.isAllDay
            ? date.formatted(date: .abbreviated, time: .omitted)
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    private func timeRange(in zone: TimeZone) -> String {
        let style = Date.IntervalFormatStyle(date: .omitted, time: .shortened, timeZone: zone)
        // 손상 데이터(종료 < 시작)에서 Range 생성 크래시를 막는다.
        return (draft.start..<max(draft.end, draft.start)).formatted(style)
    }

    // MARK: - 반복 · 알림 · 다음으로 표시

    private var repeatText: String {
        if case .custom(let rule) = draft.recurrence { return rule.summaryText }
        return draft.recurrence.label
    }

    /// 사용자 지정 알림은 메뉴 문구("사용자화") 대신 일시 자체를 보여준다.
    private func alarmText(_ alarm: EventEditDraft.Alarm) -> String {
        if case .absolute(let date) = alarm {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return alarm.label
    }

    private func showsAvailability(_ calendar: EKCalendar) -> Bool {
        EventEditDraft.availabilityOptions(for: calendar.supportedEventAvailabilities)
            .contains(draft.availability)
    }

    // MARK: - 초대받은 사람 · URL

    /// 이름(없으면 이메일) + 응답 상태. EventKit 참석자는 읽기 전용이라 표시만 한다.
    private func participantRow(_ participant: EKParticipant) -> some View {
        LabeledContent {
            if let status = statusText(participant.participantStatus) {
                Text(status)
            }
        } label: {
            Text(participant.name ?? participant.url.absoluteString.replacingOccurrences(of: "mailto:", with: ""))
                .lineLimit(1)
        }
    }

    private func statusText(_ status: EKParticipantStatus) -> String? {
        switch status {
        case .accepted: String(localized: "Accepted")
        case .declined: String(localized: "Declined")
        case .tentative: String(localized: "Maybe")
        case .pending: String(localized: "Pending")
        default: nil
        }
    }

    private var url: URL? {
        URL(string: draft.urlString.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.scheme == nil ? nil : $0 }
    }
}
