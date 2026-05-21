//
//  SettingsView.swift
//  cue / Presentation
//

import SwiftUI

/// 설정 탭 화면. 지금은 placeholder이며, 추후 설정 항목이 채워진다.
struct SettingsView: View {
    var body: some View {
        List {
            Text("설정 항목이 곧 추가됩니다.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("설정")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
