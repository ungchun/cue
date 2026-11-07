//
//  TimeZonePickerScreen.swift
//  cue / Presentation
//

import SwiftUI

/// 이벤트 시간대 선택 — 편집 폼의 "시간대" 행에서 푸시되는 검색 목록(Apple 캘린더와 같은 흐름).
///
/// 시스템이 아는 모든 시간대를 도시명(식별자 끝 부분) + 로컬라이즈된 시간대 이름으로 보여준다.
/// 도시명을 현지어로 바꾸는 공개 API는 없어 식별자 표기를 그대로 쓴다.
struct TimeZonePickerScreen: View {
    let selection: TimeZone
    let onSelect: (TimeZone) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    /// 목록 원본 — 도시명 순. 화면마다 다시 만들 필요 없어 한 번만 계산한다.
    private static let zones: [TimeZone] = TimeZone.knownTimeZoneIdentifiers
        .compactMap(TimeZone.init(identifier:))
        .sorted { cityName(for: $0).localizedStandardCompare(cityName(for: $1)) == .orderedAscending }

    var body: some View {
        List(filteredZones, id: \.identifier) { zone in
            Button {
                onSelect(zone)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(Self.cityName(for: zone))
                            .foregroundStyle(.primary)
                        Text(Self.zoneName(for: zone))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if zone.identifier == selection.identifier {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .navigationTitle("Time Zone")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }

    private var filteredZones: [TimeZone] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Self.zones }
        return Self.zones.filter {
            Self.cityName(for: $0).localizedCaseInsensitiveContains(trimmed)
                || Self.zoneName(for: $0).localizedCaseInsensitiveContains(trimmed)
                || $0.identifier.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// "Asia/Seoul" → "Seoul", "America/New_York" → "New York".
    static func cityName(for zone: TimeZone) -> String {
        let last = zone.identifier.split(separator: "/").last.map(String.init) ?? zone.identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    /// 로컬라이즈된 일반 이름("한국 표준시"류). 못 얻으면 식별자.
    static func zoneName(for zone: TimeZone) -> String {
        zone.localizedName(for: .generic, locale: .current) ?? zone.identifier
    }
}
