//
//  CalendarWidgetHeader.swift
//  cueLiveActivity
//
//  위젯 4종 공통 상단 바 — ‹ 2026년 7월 › .
//

import AppIntents
import SwiftUI

struct CalendarWidgetHeader: View {
    /// 표시 중인 달 — 월과 연도를 나눠 받는다. 레퍼런스처럼 월을 굵게, 연도를 흐리게 그린다.
    let month: String
    let year: String
    /// 좌우 이동을 담당할 위젯 종류. `nil`이면 셰브런을 그리지 않는다(고정형 월 위젯).
    var shiftKind: WidgetRangeKind?
    /// 셰브런 한 번에 움직일 양 — 월 위젯은 1개월, 3일 위젯은 3일, 1일 위젯은 1일.
    var shiftStep: Int = 1

    var body: some View {
        // 위젯 4종이 **같은 상단 바**를 갖도록, 제목 줄 아래 구분선까지 헤더가 소유한다.
        // 예전엔 월 위젯만 본문(`MonthWidgetView`) 안에서 선을 그렸고 시간표 위젯은
        // 날짜 머리글 뒤에 그려서, 두 위젯을 나란히 놓으면 선의 높이가 달랐다.
        VStack(spacing: Spacing.zero) {
            titleBar
            Rectangle()
                .fill(WidgetCalendarTheme.gridLine)
                .frame(height: WidgetCalendarTheme.hairline)
        }
    }

    /// ‹ 7월 2026년 › 한 줄.
    private var titleBar: some View {
        // 셰브런을 좌우 끝에 고정하고 제목은 폭 중앙에 — 제목 길이가 로케일마다 달라도
        // 가운데가 흔들리지 않게 overlay로 겹친다.
        HStack(spacing: Spacing.zero) {
            // `.left`/`.right`가 아니라 `.backward`/`.forward` — RTL(아랍어)에서 HStack은
            // 자동으로 뒤집히는데 방향 고정 심볼은 글리프가 그대로라, "이전"이 오른쪽 끝에서
            // 왼쪽 화살표로 남아 방향이 거꾸로 읽힌다. 이 둘은 레이아웃 방향을 따라 미러링된다.
            chevron("chevron.backward", delta: -shiftStep)
            Spacer(minLength: Spacing.zero)
            chevron("chevron.forward", delta: shiftStep)
        }
        .overlay {
            // 월과 연도를 한 단어처럼 붙여 놓으면 "7월2026년"으로 읽힌다 — 한 칸 더 띄운다.
            HStack(spacing: Spacing.sm) {
                Text(month)
                    // 연도와 같은 크기지만 굵기로 위계를 준다 — 캘린더 헤더는 격자보다
                    // 물러나 있어야 해서 크기로 강조하지 않는다.
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(year)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        // 위젯 콘텐츠 마진을 껐기 때문에(격자를 가장자리까지 쓰려고) 헤더만 따로 인셋한다 —
        // 안 그러면 둥근 모서리가 좌우 셰브런을 잘라먹는다(실기기에서 확인).
        // overlay보다 **뒤에** 붙여야 제목과 셰브런의 세로 중심이 어긋나지 않는다.
        .padding(.horizontal, Spacing.smd)
        // 제목 줄 위아래를 같은 값으로 — 아래 구분선이 헤더 안으로 들어오면서 바깥
        // VStack의 spacing이 더 이상 아래 여백을 만들어주지 않는다.
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func chevron(_ systemName: String, delta: Int) -> some View {
        if let shiftKind {
            Button(intent: ShiftWidgetRangeIntent(kind: shiftKind, delta: delta)) {
                Image(systemName: systemName)
                    .font(.footnote.weight(.semibold))
                    // 배경(순수 검정/흰색)에 맞춰 한 단계 더 흐리게 — `.secondary`는 캘린더
                    // 격자보다 튀어서 시선이 셰브런으로 먼저 간다.
                    .foregroundStyle(.tertiary)
                    // 탭 영역을 아이콘보다 넓게 — 위젯 버튼은 한 번에 맞히기 어렵다.
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, Spacing.xxs)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            // 고정형에서도 같은 자리를 비워 둬 제목의 세로 위치가 이동형과 같아진다.
            Color.clear.frame(width: Spacing.md, height: Spacing.md)
        }
    }
}
