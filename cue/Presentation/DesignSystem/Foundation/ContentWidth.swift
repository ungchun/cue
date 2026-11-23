//
//  ContentWidth.swift
//  cue / Presentation
//

import CoreGraphics

/// 폭 토큰 — 가운데 정렬 콘텐츠(입력줄·주 버튼·안내 문구)가 넓은 화면에서 끝없이
/// 늘어나지 않게 막는 상한.
///
/// iPhone Duo를 펼친 화면은 가로 약 950pt라, 폭을 다 쓰면 메모 입력줄·온보딩 버튼이
/// 화면 끝까지 늘어나 시선이 좌우로 멀어진다. 일반 iPhone은 가장 넓은 기종도 콘텐츠 폭이
/// 이 값보다 좁아(440pt − 좌우 여백) 상한에 닿지 않는다 — 기존 화면은 그대로다.
/// 기기를 묻지 않고 폭만으로 동작하므로 접기·펼치기·창 크기 변화에 그대로 따라간다.
///
/// 사용: `.frame(maxWidth: ContentWidth.readable)` — 좌우 여백(`padding`) **안쪽**에 건다.
enum ContentWidth {
    static let readable: CGFloat = 480
}
