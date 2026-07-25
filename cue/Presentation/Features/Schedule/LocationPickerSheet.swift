//
//  LocationPickerSheet.swift
//  cue / Presentation
//

import CoreLocation
import MapKit
import SwiftUI

/// 이벤트 위치 선택 시트 — Apple 캘린더의 "위치" 화면을 따른다:
/// 검색 필드 + 입력 문자열 그대로 쓰기('…') + 현재 위치 + 지도 위치(자동완성 결과).
///
/// 지도 결과는 `MKLocalSearchCompleter` 자동완성으로, 탭하면 `MKLocalSearch`로 좌표까지
/// 해석해 구조화 위치(`EventEditDraft.Location`)로 돌려준다. 현재 위치는 위치 권한을
/// 요청한 뒤 역지오코딩으로 장소명·주소를 만든다. (영상 통화(FaceTime)는 EventKit이
/// 서드파티에 열어주지 않는 캘린더 앱 전용 필드라 제외.)
struct LocationPickerSheet: View {
    let onSelect: (EventEditDraft.Location) -> Void

    @State private var searchText = ""
    @State private var search = LocationSearchModel()
    @State private var locator = CurrentLocationModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // 입력 문자열을 장소 검색 없이 그대로 쓰기 — Apple의 '개봉' 행과 동일.
                if !trimmedQuery.isEmpty {
                    Section {
                        Button {
                            select(EventEditDraft.Location(title: trimmedQuery))
                        } label: {
                            Text(verbatim: "'\(trimmedQuery)'")
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        HStack(spacing: Spacing.smd) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.tint)
                            Text("Current Location")
                                .foregroundStyle(.primary)
                            if locator.isLocating {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(locator.isLocating)
                }

                if !search.results.isEmpty {
                    Section("Map Locations") {
                        ForEach(search.results, id: \.self) { completion in
                            Button {
                                Task { await select(completion) }
                            } label: {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(completion.title)
                                        .foregroundStyle(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Enter Location")
            )
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                }
            }
            .onChange(of: searchText) { _, query in
                search.update(query: query)
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(locator.errorMessage ?? "")
            }
        }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { locator.errorMessage != nil },
            set: { if !$0 { locator.errorMessage = nil } }
        )
    }

    private func select(_ location: EventEditDraft.Location) {
        onSelect(location)
        dismiss()
    }

    /// 자동완성 항목 → 좌표 해석 후 선택. 해석 실패해도 제목·주소만으로 선택은 성립.
    private func select(_ completion: MKLocalSearchCompletion) async {
        let response = try? await MKLocalSearch(request: .init(completion: completion)).start()
        let coordinate = response?.mapItems.first?.placemark.coordinate
        select(EventEditDraft.Location(
            title: completion.title,
            address: completion.subtitle.isEmpty ? nil : completion.subtitle,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        ))
    }

    /// 현재 위치 — 권한 요청 → 1회 측위 → 역지오코딩으로 장소명·주소 구성.
    private func useCurrentLocation() async {
        do {
            let location = try await locator.requestLocation()
            let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let title = placemark?.name ?? String(localized: "Current Location")
            let address = placemark.map { pm in
                [pm.country, pm.administrativeArea, pm.locality, pm.subLocality, pm.thoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")
            }
            select(EventEditDraft.Location(
                title: title,
                address: (address?.isEmpty == false) ? address : nil,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ))
        } catch {
            locator.errorMessage = String(localized: "Couldn't determine your location.")
        }
    }
}

/// 지도 자동완성 — `MKLocalSearchCompleter` 래퍼. delegate 콜백은 메인 큐로 온다.
@MainActor
@Observable
private final class LocationSearchModel: NSObject, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    var results: [MKLocalSearchCompletion] = []

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            completer.cancel()
            results = []
        } else {
            completer.queryFragment = trimmed
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // 파라미터 대신 자기 프로퍼티 접근 — non-Sendable 값을 액터 경계로 보내지 않는다
        // (콜백은 메인 큐로 오고, self.completer === completer).
        MainActor.assumeIsolated {
            results = self.completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            results = []
        }
    }
}

/// 현재 위치 1회 측위 — 권한 요청부터 위치 콜백까지를 async 하나로 감싼다.
/// delegate 콜백은 매니저를 만든 메인 런루프로 온다.
@MainActor
@Observable
private final class CurrentLocationModel: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, any Error>?
    var isLocating = false
    var errorMessage: String?

    enum LocationError: Error { case denied, unavailable }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() async throws -> CLLocation {
        guard continuation == nil else { throw LocationError.unavailable }   // 중복 요청 방지
        isLocating = true
        defer { isLocating = false }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()   // 결과는 didChangeAuthorization에서
            case .denied, .restricted:
                finish(.failure(LocationError.denied))
            default:
                manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 파라미터 대신 자기 프로퍼티 접근 — non-Sendable 값을 액터 경계로 보내지 않는다
        // (콜백은 매니저를 만든 메인 런루프로 오고, self.manager === manager).
        MainActor.assumeIsolated {
            guard continuation != nil else { return }
            switch self.manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                finish(.failure(LocationError.denied))
            default:
                break   // notDetermined — 사용자가 아직 선택 중
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            if let location = locations.last {
                finish(.success(location))
            } else {
                finish(.failure(LocationError.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            finish(.failure(error))
        }
    }
}
