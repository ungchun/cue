//
//  FetchWeatherAttributionUseCase.swift
//  cue / Domain
//

/// 날씨 데이터 출처 표기(마크·법적 고지 링크)를 가져온다.
struct FetchWeatherAttributionUseCase: Sendable {
    private let repository: any WeatherRepository

    init(repository: any WeatherRepository) {
        self.repository = repository
    }

    func callAsFunction() async throws -> WeatherDataAttribution {
        try await repository.attribution()
    }
}
