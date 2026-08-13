//
//  UpcomingListMetrics.swift
//  cue / Shared
//

import UIKit

/// 사이드 목록(`WidgetItemListView`)이 몇 줄을 세우는지.
///
/// 개수를 프로바이더가 **조회 전에** 알아야 하므로(→ `UpcomingItemPicker`의 `limit`)
/// 뷰가 스스로 정할 수 없다. 그래서 여기 둔다.
///
/// ⚠️ 높이는 계산하지 않는다. 예전엔 기기 높이를 상수로 박아 몇 줄이 들어가는지
/// 역산했는데, 그 상수가 실제 위젯보다 작아 캘린더가 쪼그라들고 목록은 여전히 넘쳤다.
/// 지금은 줄들이 **주어진 높이를 균등하게 나눠 가지므로**(→ `WidgetItemListView`)
/// 몇 pt인지 알 필요가 없다 — 네 줄은 어떤 기기에서든 네 줄이다.
enum UpcomingListMetrics {

    /// 목록에 세우는 줄 수 — 넷(제품 요구).
    ///
    /// 기기 높이와 무관하게 고정이다. 높이에서 역산하면 좁은 기기에서 조용히 셋으로
    /// 줄어드는데, 그건 기기마다 다른 위젯이 된다는 뜻이다.
    static let rowCount = 4
}
