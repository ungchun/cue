//
//  WeatherDataAttribution.swift
//  cue / Domain
//

import Foundation

/// 날씨 데이터 출처 표기 — WeatherKit 약관상 날씨를 보여주는 앱은 Apple 날씨 마크와
/// 법적 고지 링크를 앱 안에 표시해야 한다. 상표 문구(" Weather")는 화면이 고정 영어로 그린다.
struct WeatherDataAttribution: Equatable, Sendable {
    let legalPageURL: URL
}
