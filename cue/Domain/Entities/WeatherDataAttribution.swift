//
//  WeatherDataAttribution.swift
//  cue / Domain
//

import Foundation

/// 날씨 데이터 출처 표기 — WeatherKit 약관상 날씨를 보여주는 앱은 Apple 날씨 마크와
/// 법적 고지 링크를 앱 안에 표시해야 한다. 마크는 이미지 대신 서비스 이름(" Weather")
/// 텍스트로 쓴다 — 글자 크기·라이트/다크를 시스템 텍스트가 알아서 따라간다.
struct WeatherDataAttribution: Equatable, Sendable {
    /// Apple 로고 글리프가 붙은 서비스 이름 — " Weather".
    let serviceName: String
    let legalPageURL: URL
}
