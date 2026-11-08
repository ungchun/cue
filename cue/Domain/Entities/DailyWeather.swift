//
//  DailyWeather.swift
//  cue / Domain
//

import Foundation

/// 하루치 날씨 예보 — 월 캘린더 날짜 칸에 아이콘 하나로 그린다.
struct DailyWeather: Equatable, Sendable {
    /// 그날 자정(기기 시간대).
    let date: Date
    /// 날씨 상태 SF Symbol 이름("cloud.rain" 등) — 예보 출처가 주는 값을 그대로 쓴다.
    let symbolName: String
}
