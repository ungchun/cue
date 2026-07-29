//
//  WidgetBuildStamp.swift
//  cueLiveActivity
//
//  ⚠️ 임시 파일 — 위젯 헤더에 빌드 번호를 찍어 반영 여부를 눈으로 확인한다.
//
//  위젯은 코드를 고쳐도 홈 화면 인스턴스가 바로 갱신되지 않는 경우가 있어서,
//  "고쳤는데 화면이 그대로"일 때 원인이 코드인지 갱신인지 가리기 어렵다.
//  이 번호가 올라가 있으면 빌드가 반영된 것이다.
//
//  작업을 한 번 마칠 때마다 `number`를 1씩 올린다.
//  확인이 끝나면 이 파일과 `CalendarWidgetHeader`의 표시부를 함께 지운다.
//

enum WidgetBuildStamp {
    static let number = 10
}
