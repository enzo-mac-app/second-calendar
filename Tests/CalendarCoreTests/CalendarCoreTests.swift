import XCTest
@testable import CalendarCore

final class YMDTests: XCTestCase {
    func testWeekdayAndArithmetic() {
        XCTAssertEqual(YMD(2026, 11, 23).weekday, 2)           // Monday
        XCTAssertEqual(YMD(2026, 2, 28).adding(days: 1), YMD(2026, 3, 1))
        XCTAssertEqual(YMD(2028, 2, 28).adding(days: 1), YMD(2028, 2, 29))
        XCTAssertEqual(YMD(2026, 12, 31).adding(days: 1), YMD(2027, 1, 1))
        XCTAssertEqual(YMD(2026, 11, 23).days(until: YMD(2027, 1, 1)), 39)
        XCTAssertEqual(YMD(2026, 1, 15).month(offset: -1), YMD(2025, 12, 1))
        XCTAssertEqual(YMD(2026, 12, 15).month(offset: 1), YMD(2027, 1, 1))
        XCTAssertEqual(YMD(iso: "2027/9/23"), YMD(2027, 9, 23))
        XCTAssertNil(YMD(iso: "nope"))
    }

    func testMonthGrid() {
        // 1 Nov 2026 is a Sunday.
        let mondayFirst = MonthGrid.days(year: 2026, month: 11, firstWeekday: 2)
        XCTAssertEqual(mondayFirst.count, 42)
        XCTAssertEqual(mondayFirst.first, YMD(2026, 10, 26))
        let sundayFirst = MonthGrid.days(year: 2026, month: 11, firstWeekday: 1)
        XCTAssertEqual(sundayFirst.first, YMD(2026, 11, 1))
        XCTAssertEqual(MonthGrid.weekdayOrder(firstWeekday: 2), [2, 3, 4, 5, 6, 7, 1])
    }
}

final class HolidayTests: XCTestCase {
    let store = HolidayStore(cacheDirectory: nil)

    func names(_ day: YMD, _ region: Region) -> [String] {
        store.marks(on: day, region: region).map(\.sourceName)
    }

    func testUSRules() {
        XCTAssertEqual(names(YMD(2026, 11, 26), .us).first, "Thanksgiving")
        XCTAssertEqual(names(YMD(2026, 1, 19), .us), ["Martin Luther King Jr. Day"])
        XCTAssertEqual(names(YMD(2026, 5, 25), .us), ["Memorial Day"])
        XCTAssertEqual(names(YMD(2026, 9, 7), .us), ["Labor Day"])
        // 4 July 2026 is a Saturday, so Friday the 3rd is the day off.
        let observed = store.marks(on: YMD(2026, 7, 3), region: .us)
        XCTAssertEqual(observed.first?.observed, true)
        XCTAssertTrue(store.isOffDay(YMD(2026, 7, 3), region: .us))
        // 1 Jan 2028 is a Saturday: observed on Friday 31 Dec 2027.
        XCTAssertTrue(names(YMD(2027, 12, 31), .us).contains("New Year's Day"))
        // Mother's Day is a Sunday observance, not a holiday.
        let mothers = store.marks(on: YMD(2026, 5, 10), region: .us)
        XCTAssertEqual(mothers.first?.kind, .observance)
        XCTAssertFalse(store.isOffDay(YMD(2026, 11, 24), region: .us))
    }

    func testChinaMakeUpWorkdays() {
        XCTAssertTrue(store.isOffDay(YMD(2026, 10, 1), region: .cn))
        // Sunday 4 Jan 2026 is a 调休 workday.
        XCTAssertEqual(YMD(2026, 1, 4).weekday, 1)
        XCTAssertEqual(store.marks(on: YMD(2026, 1, 4), region: .cn).first?.kind, .workday)
        XCTAssertFalse(store.isOffDay(YMD(2026, 1, 4), region: .cn))
        XCTAssertNotNil(store.coveredYears(.cn))
        XCTAssertTrue(store.hasData(.cn, year: 2027))
    }

    func testJapan() {
        XCTAssertEqual(names(YMD(2027, 9, 23), .jp), ["秋分の日"])
        // 3 May 2026 is a Sunday, so 6 May is a substitute holiday.
        XCTAssertEqual(names(YMD(2026, 5, 6), .jp), ["休日"])
        XCTAssertTrue(store.isOffDay(YMD(2026, 5, 6), region: .jp))
    }

    func testNamesFollowLanguage() {
        let national = store.marks(on: YMD(2026, 10, 1), region: .cn).first!
        XCTAssertEqual(national.name(.en), "National Day")
        XCTAssertEqual(national.name(.ja), "国慶節")
        let combined = HolidayMark(region: .cn, kind: .off, sourceName: "国庆节、中秋节")
        XCTAssertEqual(combined.name(.en), "National Day & Mid-Autumn Festival")
        let thanks = store.marks(on: YMD(2026, 11, 26), region: .us).first!
        XCTAssertEqual(thanks.name(.zh), "感恩节")
        XCTAssertEqual(store.marks(on: YMD(2027, 9, 23), region: .jp).first!.name(.zh), "秋分日")
    }

    func testNextHolidaySkipsTheOneYouAreIn() {
        let next = store.nextHoliday(after: YMD(2026, 11, 23), region: .cn)
        XCTAssertEqual(next?.day, YMD(2027, 1, 1))
        XCTAssertEqual(next?.mark.sourceName, "元旦")
        // In the middle of 国庆节 the next one is a different holiday.
        let during = store.nextHoliday(after: YMD(2026, 10, 2), region: .cn)
        XCTAssertNotEqual(during?.mark.sourceName, "国庆节")
    }

    func testParsersRejectJunk() {
        XCTAssertThrowsError(try CNHolidays.parse(Data("<html>".utf8)))
        XCTAssertTrue(JPHolidays.parse(csv: "国民の祝日・休日月日,国民の祝日・休日名称\nhello").isEmpty)
    }
}

final class LunarTests: XCTestCase {
    func testFestivalsAndLabels() {
        XCTAssertEqual(LunarDay(YMD(2026, 2, 17)).cellLabel, "春节")
        XCTAssertTrue(LunarDay(YMD(2026, 9, 25)).festivals.contains("中秋节"))
        XCTAssertEqual(LunarDay(YMD(2026, 2, 16)).cellLabel, "除夕")
        let d = LunarDay(YMD(2026, 11, 23))
        XCTAssertTrue(d.monthName.hasSuffix("月"))
        XCTAssertTrue(d.fullDescription.hasPrefix("农历"))
        XCTAssertEqual(d.zodiac, "马")
        XCTAssertEqual(LunarDay(YMD(2027, 1, 1)).cellLabel, "元旦")
    }
}

final class ColleagueTests: XCTestCase {
    let store = HolidayStore(cacheDirectory: nil)
    let shanghai = TimeZone(identifier: "Asia/Shanghai")!

    func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testNewYork() {
        let ny = Colleague(cityID: "new_york")
        // Tue 24 Nov 2026, 10:00 in New York.
        let working = ny.status(at: date("2026-11-24T15:00:00Z"), store: store, myTimeZone: shanghai)!
        XCTAssertEqual(working.state, .working)
        XCTAssertEqual(working.timeString, "10:00")
        XCTAssertEqual(working.dayOffset, 0)     // 23:00 Tuesday in Shanghai too
        // Mon 23 Nov, 22:00 in New York while it's already Tuesday 11:00 in Shanghai.
        let late = ny.status(at: date("2026-11-24T03:00:00Z"), store: store, myTimeZone: shanghai)!
        XCTAssertEqual(late.state, .offHours)
        XCTAssertEqual(late.dayOffset, -1)
        // Thanksgiving.
        let thanks = ny.status(at: date("2026-11-26T15:00:00Z"), store: store)!
        if case .holiday(let mark) = thanks.state { XCTAssertEqual(mark.sourceName, "Thanksgiving") } else { XCTFail() }
    }

    func testChinaWorkdayWeekend() {
        let bj = Colleague(cityID: "beijing")
        // Sunday 4 Jan 2026, 10:00 Beijing: a make-up workday.
        XCTAssertEqual(bj.status(at: date("2026-01-04T02:00:00Z"), store: store)!.state, .working)
        // Saturday 10 Jan 2026: an ordinary weekend.
        XCTAssertEqual(bj.status(at: date("2026-01-10T02:00:00Z"), store: store)!.state, .weekend)
    }

    func testCityWithoutHolidays() {
        let london = Colleague(cityID: "london")
        XCTAssertNotNil(london.status(at: Date(), store: store))
        XCTAssertNil(Colleague(cityID: "atlantis").status(at: Date(), store: store))
    }
}

final class MeetingLinkTests: XCTestCase {
    func testFindsCallLinks() {
        XCTAssertEqual(MeetingLink.find(in: [nil, "Agenda: https://example.com/doc", "Join https://us02web.zoom.us/j/123456?pwd=x"])?.host,
                       "us02web.zoom.us")
        XCTAssertEqual(MeetingLink.find(in: ["https://meet.google.com/abc-defg-hij"])?.host, "meet.google.com")
        XCTAssertEqual(MeetingLink.find(in: ["会议链接 https://meeting.tencent.com/dm/abc"])?.host, "meeting.tencent.com")
        XCTAssertNil(MeetingLink.find(in: ["https://example.com", nil, ""]))
    }
}
