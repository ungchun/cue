//
//  ReminderView.swift
//  cue / Presentation
//

import SwiftUI

/// 미리알림 탭 화면. 지금은 placeholder이며, 추후 Cue 목록의 집이 된다.
struct ReminderView: View {
    var body: some View {
        ContentUnavailableView(
            "미리알림 없음",
            systemImage: "bell",
            description: Text("띄워둘 Cue를 추가해 보세요.")
        )
        .navigationTitle("미리알림")
    }
}

#Preview {
    NavigationStack {
        ReminderView()
    }
}
