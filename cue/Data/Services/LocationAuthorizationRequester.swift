//
//  LocationAuthorizationRequester.swift
//  cue / Data
//

import CoreLocation

/// 위치 권한(앱 사용 중) 요청을 async 한 번으로 감싼다 — 결정돼 있으면 묻지 않고 바로 돌려준다.
///
/// `CLLocationManager`는 만든 스레드의 런루프로 콜백하므로 메인에서 만들고 쓴다.
@MainActor
final class LocationAuthorizationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Bool, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    /// 허용(앱 사용 중·항상)이면 true. 미결정이면 시스템 프롬프트를 띄우고 응답을 기다린다.
    func request() async -> Bool {
        if let granted = Self.decision(manager.authorizationStatus) { return granted }
        // 이미 기다리는 요청이 있으면 새로 묻지 않는다 — 같은 응답을 함께 받지 못하니 거부로 본다.
        guard continuation == nil else { return false }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            // 델리게이트를 붙이는 순간에도 한 번 불린다(미결정) — 결정될 때만 응답한다.
            guard let granted = Self.decision(status), let continuation = self.continuation else { return }
            self.continuation = nil
            continuation.resume(returning: granted)
        }
    }

    /// 결정된 상태면 허용 여부, 미결정이면 nil.
    private static func decision(_ status: CLAuthorizationStatus) -> Bool? {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways: true
        case .denied, .restricted: false
        case .notDetermined: nil
        @unknown default: false
        }
    }
}
