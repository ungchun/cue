//
//  FetchDailyWeatherUseCase.swift
//  cue / Domain
//

/// 현재 위치의 일별 날씨 예보를 가져온다.
struct FetchDailyWeatherUseCase: Sendable {
    private let repository: any WeatherRepository

    init(repository: any WeatherRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> [DailyWeather] {
        try await repository.dailyForecast()
    }
}
