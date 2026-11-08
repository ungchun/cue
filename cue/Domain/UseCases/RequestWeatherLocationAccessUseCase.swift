//
//  RequestWeatherLocationAccessUseCase.swift
//  cue / Domain
//

/// 위치 권한 요청 — 월 캘린더 날씨 표시를 켤 때 부른다. 허용됐으면 true.
struct RequestWeatherLocationAccessUseCase: Sendable {
    private let repository: any WeatherRepository

    init(repository: any WeatherRepository) {
        self.repository = repository
    }

    func callAsFunction() async -> Bool {
        await repository.requestLocationAccess()
    }
}
