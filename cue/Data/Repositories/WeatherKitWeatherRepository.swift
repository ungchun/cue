//
//  WeatherKitWeatherRepository.swift
//  cue / Data
//

import CoreLocation
import Foundation
import WeatherKit

/// WeatherKit 구현 — 현재 위치의 일별 예보를 받는다.
///
/// - 위치: 날씨용이라 대략(1km) 위치면 충분하다. 권한이 없으면 묻지 않고 던진다 —
///   묻는 건 설정에서 날씨 표시를 켤 때(`requestLocationAccess`)뿐이다.
/// - 캐시: 1시간 — 월 캘린더는 진입·포그라운드 복귀마다 다시 읽는데, 예보는 그만큼 자주 바뀌지 않고
///   WeatherKit 호출은 월 사용량 한도가 있다.
actor WeatherKitWeatherRepository: WeatherRepository {
    private let service = WeatherService.shared
    private static let cacheLifetime: TimeInterval = 60 * 60

    private var cached: (fetchedAt: Date, forecast: [DailyWeather])?
    /// 권한 요청기 — 메인 액터에서 만들어야 해 처음 쓸 때 만든다.
    private var requester: LocationAuthorizationRequester?

    func requestLocationAccess() async -> Bool {
        let requester = await currentRequester()
        return await requester.request()
    }

    func dailyForecast() async throws -> [DailyWeather] {
        if let cached, Date().timeIntervalSince(cached.fetchedAt) < Self.cacheLifetime {
            return cached.forecast
        }
        let location = try await currentLocation()
        let daily = try await service.weather(for: location, including: .daily)
        let calendar = Calendar.current
        let forecast = daily.map { day in
            DailyWeather(date: calendar.startOfDay(for: day.date), symbolName: day.symbolName)
        }
        cached = (Date(), forecast)
        return forecast
    }

    func attribution() async throws -> WeatherDataAttribution {
        let attribution = try await service.attribution
        return WeatherDataAttribution(
            markLightURL: attribution.combinedMarkLightURL,
            markDarkURL: attribution.combinedMarkDarkURL,
            legalPageURL: attribution.legalPageURL
        )
    }

    private func currentRequester() async -> LocationAuthorizationRequester {
        if let requester { return requester }
        let made = await MainActor.run { LocationAuthorizationRequester() }
        requester = made
        return made
    }

    /// 첫 위치 하나만 받는다. 권한이 없으면 프롬프트 없이 실패한다.
    private func currentLocation() async throws -> CLLocation {
        let status = await MainActor.run { CLLocationManager().authorizationStatus }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            throw CLError(.denied)
        }
        for try await update in CLLocationUpdate.liveUpdates(.default) {
            if let location = update.location { return location }
        }
        throw CLError(.locationUnknown)
    }
}
