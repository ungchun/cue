//
//  RefreshLiveIntent.swift
//  cue / Shared
//

import AppIntents
import Foundation

/// 단축어 앱에 노출되는 「라이브 새로고침」 — 8시간 뒤 시스템이 끄는 라이브를 되살린다.
///
/// 설정 ▸ 「24시간 사용하기」 안내가 사용자에게 만들게 하는 자동화가 이걸 실행한다
/// (00:00 · 08:00 · 16:00 하루 세 번). 안내 문구의 단축어 이름과 `title`이 **같아야**
/// 사용자가 목록에서 찾을 수 있다.
///
/// **`LiveActivityIntent`인 이유** — 평범한 `AppIntent`로는 백그라운드에서 라이브를 시작할
/// 수 없다(`openAppWhenRun = false`면 iOS 18에서 `perform()`이 아예 안 불리는 사례도 보고됐다).
/// 이 프로토콜을 채택하면 **사용자가 단축어·Siri로 직접 실행한 경우** 시스템이 앱을 백그라운드로
/// 깨우고 라이브 시작 권한까지 부여한다 — 앱을 포그라운드로 끌어올 필요가 없다.
/// 같은 이유로 `CompleteReminderIntent`·`ShiftCalendarMonthIntent`도 이 프로토콜을 쓴다.
///
/// **왜 앱을 안 여는가** — 자동화는 사용자가 잠든 시간대에 도는 게 보통이다. 그때마다 앱이
/// 튀어나오면 잠금화면을 덮고, 사용자는 자기가 뭘 눌렀는지 모른 채 앱을 닫아야 한다.
struct RefreshLiveIntent: LiveActivityIntent {
    /// 단축어 목록에 뜨는 이름 — 「24시간 사용하기」 안내의 3단계 문구와 일치해야 한다.
    static let title: LocalizedStringResource = "Refresh Live"
    static let description = IntentDescription("Republishes your Live so it keeps running past the 8-hour system limit.")

    /// 단축어 갤러리에 노출한다 — 이 인텐트의 존재 이유가 사용자 자동화다.
    static let isDiscoverable = true
    /// 백그라운드에서 처리한다(위 주석 참고).
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await RefreshLiveActivityRunner.run()
        return .result()
    }
}

/// 단축어 앱 목록에 Cue의 인텐트를 등록한다.
///
/// **이게 없으면 인텐트를 만들어도 단축어 앱에 나타나지 않는다** — `AppIntent` 정의만으로는
/// 부족하고, 앱이 자신의 단축어를 시스템에 광고해야 한다.
///
/// **번역은 `AppShortcuts.xcstrings`에 있다** — 여기 문자열만 다른 카탈로그를 쓴다.
/// 시스템이 Siri 음성 인식을 위해 앱 실행 전에 미리 읽어가야 해서 Apple이 파일을 따로
/// 요구한다. `Localizable.xcstrings`에 넣으면 조용히 무시돼 영어로만 인식된다.
struct CueAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RefreshLiveIntent(),
            // 음성 문구에는 `.applicationName`이 반드시 들어가야 한다(시스템 요구사항).
            // 한국어 등 번역은 카탈로그가 대체하므로 여기엔 영어만 둔다 — 문자열을 직접
            // 박아 넣으면 그 언어에서만 동작하고 나머지 15개 언어는 비어버린다.
            phrases: ["Refresh \(.applicationName) Live"],
            shortTitle: "Refresh Live",
            systemImageName: "clock.arrow.2.circlepath"
        )
    }
}
