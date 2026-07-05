//
//  KoreanHolidayCalculator.swift
//  cue / Shared
//

import Foundation

/// 한국 법정공휴일(양력·음력·대체공휴일)을 순수 계산으로 뽑아내는 계산기.
///
/// Live Activity 위젯이 달력 날짜를 빨간색으로 칠할 때 쓴다. 위젯 익스텐션과 앱 본체
/// **두 타깃 모두에 컴파일**되므로 의존은 `Foundation`뿐 — SwiftUI·EventKit·네트워크를
/// 쓰지 않는다. 음력 변환은 Foundation에 내장된 `Calendar(identifier: .dangi)`
/// (한국 음력)만으로 처리해 외부 데이터·API가 필요 없다.
///
/// **범위 밖(의도적 제외)**: 선거일·임시공휴일 같은 그해에만 지정되는 일회성 공휴일은
/// 규칙으로 계산할 수 없으므로 다루지 않는다. 매년 반복되는 법정공휴일만 대상으로 한다.
///
/// **대체공휴일**은 현행 「공휴일에 관한 법률」 기준을 연도 구분 없이 전 연도에 적용한다
/// (과거 시행 시점 컷오프 없음).
enum KoreanHolidayCalculator {

    /// 주어진 양력 연·월의 공휴일 **일(day-of-month) 집합**을 돌려준다.
    ///
    /// 대체공휴일은 다음 달로 넘어갈 수 있으므로 내부적으로 **해당 연도 전체**를 계산한 뒤
    /// 요청한 달만 걸러낸다. 설날처럼 1월에 걸리는 음력 공휴일도 그해 계산에 포함된다.
    static func holidayDays(year: Int, month: Int, calendar: Calendar = .current) -> Set<Int> {
        let gregorian = gregorianCalendar(basedOn: calendar)
        var days = Set<Int>()
        for date in holidayDates(year: year, calendar: calendar) {
            let parts = gregorian.dateComponents([.year, .month, .day], from: date)
            if parts.year == year, parts.month == month, let day = parts.day {
                days.insert(day)
            }
        }
        return days
    }

    /// 그해 모든 공휴일(대체공휴일 포함)을 양력 날짜(정오 기준)로 반환한다 — 달 필터 전 단계.
    /// 테스트에서 특정 날짜 유무를 직접 검증할 수 있게 internal로 노출한다.
    static func holidayDates(year: Int, calendar: Calendar = .current) -> Set<Date> {
        let gregorian = gregorianCalendar(basedOn: calendar)
        let dangi = dangiCalendar(basedOn: calendar)

        // 고정 양력 공휴일 — 대체공휴일이 붙는 것(individual)과 안 붙는 것(신정·현충일)을 나눈다.
        let noSubstitute = [
            gregorian.date(year, 1, 1),   // 신정
            gregorian.date(year, 6, 6),   // 현충일
        ]
        var individual = [
            gregorian.date(year, 3, 1),   // 삼일절
            gregorian.date(year, 5, 5),   // 어린이날
            gregorian.date(year, 8, 15),  // 광복절
            gregorian.date(year, 10, 3),  // 개천절
            gregorian.date(year, 10, 9),  // 한글날
            gregorian.date(year, 12, 25), // 성탄절
        ]
        individual.append(lunarDate(year: year, month: 4, day: 8,      // 부처님오신날
                                    gregorian: gregorian, dangi: dangi))

        // 음력 연휴 — 설날·추석은 당일과 그 전날·다음날 3일이 한 묶음(block).
        let seollal = lunarDate(year: year, month: 1, day: 1, gregorian: gregorian, dangi: dangi)
        let chuseok = lunarDate(year: year, month: 8, day: 15, gregorian: gregorian, dangi: dangi)
        let blocks = [threeDayBlock(around: seollal, gregorian: gregorian),
                      threeDayBlock(around: chuseok, gregorian: gregorian)]

        let base = noSubstitute + individual + blocks.flatMap { $0 }

        // 겹침 판정용 — 한 날짜에 원래 공휴일이 둘 이상 몰렸는지(예: 어린이날·부처님오신날 동일).
        var sourceCount: [Date: Int] = [:]
        for date in base { sourceCount[gregorian.startOfDay(for: date), default: 0] += 1 }

        var result = Set(base.map { gregorian.startOfDay(for: $0) })

        // 연휴(설날·추석) 대체: 묶음 중 **일요일이거나 다른 공휴일과 겹치는** 날 수만큼,
        // 묶음 끝 다음부터 **일요일도 이미 공휴일도 아닌** 첫 날들을 채워 넣는다(토요일은 허용).
        for block in blocks {
            let triggers = block.filter {
                gregorian.isSunday($0) || (sourceCount[gregorian.startOfDay(for: $0)] ?? 0) > 1
            }.count
            guard triggers > 0, let last = block.last else { continue }
            var cursor = last
            var added = 0
            while added < triggers {
                cursor = gregorian.nextDay(cursor)
                if gregorian.isSunday(cursor) { continue }
                if result.contains(gregorian.startOfDay(for: cursor)) { continue }
                result.insert(gregorian.startOfDay(for: cursor))
                added += 1
            }
        }

        // 개별 공휴일 대체: **토·일요일이거나 다른 공휴일과 겹치면**, 그 뒤 **주말도 이미
        // 공휴일도 아닌** 첫 평일을 추가한다. 같은 날짜에 두 공휴일이 겹쳐도 대체는 하루만
        // 나오도록 날짜 단위(중복 제거)로 순회한다.
        let individualDays = Set(individual.map { gregorian.startOfDay(for: $0) }).sorted()
        for day in individualDays {
            let triggered = gregorian.isWeekend(day) || (sourceCount[day] ?? 0) > 1
            guard triggered else { continue }
            var cursor = day
            while true {
                cursor = gregorian.nextDay(cursor)
                if gregorian.isWeekend(cursor) { continue }
                if result.contains(gregorian.startOfDay(for: cursor)) { continue }
                result.insert(gregorian.startOfDay(for: cursor))
                break
            }
        }

        return result
    }

    // MARK: - 음력 변환

    /// 양력 `year`에 해당하는 음력 `month`/`day`의 양력 날짜(정오).
    ///
    /// Foundation의 `.dangi` 달력은 연도를 60간지 순환값(1~60)으로 표현해 세기 구분이
    /// 모호하다. 그래서 그해 한여름(7/1) 날짜에서 **era+year를 뽑아 고정**한 뒤 그 음력
    /// 연도의 `month`/`day`를 만든다 — 설날·부처님오신날·추석은 모두 같은 음력 연도에
    /// 속하므로 이 방식이 세기를 정확히 짚는다.
    private static func lunarDate(year: Int, month: Int, day: Int,
                                  gregorian: Calendar, dangi: Calendar) -> Date {
        let anchor = gregorian.date(year, 7, 1)
        let era = dangi.dateComponents([.era, .year], from: anchor)
        var comps = DateComponents()
        comps.era = era.era
        comps.year = era.year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return dangi.date(from: comps) ?? anchor
    }

    /// 당일과 전날·다음날을 묶은 3일 연휴(양력).
    private static func threeDayBlock(around date: Date, gregorian: Calendar) -> [Date] {
        [gregorian.previousDay(date), date, gregorian.nextDay(date)]
    }

    // MARK: - 달력 준비

    /// 입력 달력의 시간대를 물려받은 그레고리력 — 입력이 어떤 identifier든 양력 연·월·일을
    /// 일관되게 계산한다.
    private static func gregorianCalendar(basedOn calendar: Calendar) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        gregorian.locale = calendar.locale
        return gregorian
    }

    /// 입력 달력의 시간대를 물려받은 한국 음력(dangi) 달력.
    private static func dangiCalendar(basedOn calendar: Calendar) -> Calendar {
        var dangi = Calendar(identifier: .dangi)
        dangi.timeZone = calendar.timeZone
        return dangi
    }
}

private extension Calendar {
    /// 정오로 고정한 양력 날짜 — 시간대 경계에서 날짜가 밀리지 않게.
    func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        return date(from: comps) ?? Date(timeIntervalSince1970: 0)
    }
    func nextDay(_ date: Date) -> Date { self.date(byAdding: .day, value: 1, to: date) ?? date }
    func previousDay(_ date: Date) -> Date { self.date(byAdding: .day, value: -1, to: date) ?? date }
    func isSunday(_ date: Date) -> Bool { component(.weekday, from: date) == 1 }
    func isWeekend(_ date: Date) -> Bool {
        let weekday = component(.weekday, from: date)
        return weekday == 1 || weekday == 7   // 일요일(1) 또는 토요일(7)
    }
}
