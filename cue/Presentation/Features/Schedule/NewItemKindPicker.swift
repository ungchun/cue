//
//  NewItemKindPicker.swift
//  cue / Presentation
//

import SwiftUI

/// + 시트 상단 가운데의 일정/할일 세그먼트. 선택은 들고 있지 않는다 — 시트마다 자기 종류를
/// 넘기고, 다른 쪽을 고르면 `onSelect`로 알려 컨테이너(NewItemSheet)가 시트를 바꾼다.
struct NewItemKindPicker: View {
    let kind: NewItemKind
    let onSelect: (NewItemKind) -> Void

    var body: some View {
        Picker(selection: Binding(get: { kind }, set: { if $0 != kind { onSelect($0) } })) {
            Text("Schedule").tag(NewItemKind.event)
            Text("Tasks").tag(NewItemKind.reminder)
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }
}
