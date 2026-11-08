//
//  WeatherRepository.swift
//  cue / Domain
//

/// 현재 위치의 날씨 예보 저장소 추상화 — Domain이 소유하는 프로토콜. 구현은 Data 계층(WeatherKit·CoreLocation).
protocol WeatherRepository: Sendable {
    /// 위치 권한(앱 사용 중)을 요청한다(필요 시 시스템 프롬프트). 허용됐으면 true.
    func requestLocationAccess() async -> Bool
    /// 오늘부터의 일별 예보(출처가 주는 만큼, WeatherKit은 10일). 위치 권한이 없으면 던진다.
    func dailyForecast() async throws -> [DailyWeather]
    /// 출처 표기용 마크·링크.
    func attribution() async throws -> WeatherDataAttribution
}
