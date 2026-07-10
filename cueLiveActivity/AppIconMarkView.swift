//
//  AppIconMarkView.swift
//  cueLiveActivity
//
//  Dynamic Island compact/minimal 자리의 앱 아이콘 마크 — 형상화 벡터가 아니라 실제
//  앱 아이콘 이미지(가운데 원 부분 크롭, `AppIconMark` 에셋)를 원형으로 잘라 그린다.
//  할일/일정/메모 위젯이 공유한다.
//

import SwiftUI

struct AppIconMarkView: View {
    var body: some View {
        Image("AppIconMark")
            .resizable()
            .scaledToFit()
            .clipShape(Circle())
    }
}
