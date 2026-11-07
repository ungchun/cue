//
//  ReminderLocationAlarm.swift
//  cue / Domain
//

import Foundation

/// 위치 기반 알림 — "이 장소에 도착할 때/떠날 때" 울리는 미리 알림 알람 하나.
///
/// EventKit의 `EKAlarm.structuredLocation` + `proximity`에 대응한다. 미리 알림 앱처럼
/// 항목당 하나만 다룬다(여러 개면 첫 번째만 읽고, 나머지는 저장 시 건드리지 않는다).
struct ReminderLocationAlarm: Equatable, Sendable, Codable {
    /// 장소 이름(예: "집", "회사").
    var title: String
    /// 사람이 읽는 주소. 이름만 있는 장소면 nil.
    var address: String?
    var latitude: Double
    var longitude: Double
    /// 반경(미터). nil이면 시스템 기본 반경.
    var radius: Double?
    var proximity: Proximity

    /// 언제 울릴지 — 도착·출발. EventKit `EKAlarmProximity`의 enter/leave와 1:1.
    enum Proximity: String, Sendable, Codable {
        case arriving
        case leaving
    }
}
