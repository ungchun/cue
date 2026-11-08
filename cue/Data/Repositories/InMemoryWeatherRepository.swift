//
//  InMemoryWeatherRepository.swift
//  cue / Data
//

import Foundation

/// 프리뷰·테스트용 인메모리 구현. WeatherKit·위치 권한 없이 동작한다.
actor InMemoryWeatherRepository: WeatherRepository {
    private let grantsAccess: Bool
    private var forecast: [DailyWeather]
    private var fails: Bool
    /// 테스트 관측점 — 권한 요청·예보 조회 횟수.
    private(set) var accessRequestCount = 0
    private(set) var forecastFetchCount = 0

    init(grantsAccess: Bool = true, forecast: [DailyWeather] = [], fails: Bool = false) {
        self.grantsAccess = grantsAccess
        self.forecast = forecast
        self.fails = fails
    }

    func requestLocationAccess() async -> Bool {
        accessRequestCount += 1
        return grantsAccess
    }

    func dailyForecast() async throws -> [DailyWeather] {
        forecastFetchCount += 1
        if fails { throw URLError(.notConnectedToInternet) }
        return forecast
    }

    func attribution() async throws -> WeatherDataAttribution {
        if fails { throw URLError(.notConnectedToInternet) }
        let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html")!
        return WeatherDataAttribution(serviceName: "\u{F8FF} Weather", legalPageURL: url)
    }

    /// 테스트 훅 — 예보를 바꾼다.
    func setForecast(_ forecast: [DailyWeather]) {
        self.forecast = forecast
    }
}
