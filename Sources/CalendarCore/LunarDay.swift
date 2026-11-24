import Foundation
import LunarSwift

/// The Chinese lunar side of one day.
public struct LunarDay: Sendable, Hashable {
    /// 正月 … 腊月, with 闰 for leap months.
    public let monthName: String
    /// 初一 … 三十.
    public let dayName: String
    /// 春节, 元宵节, 端午节, 七夕节, 中秋节, 重阳节, 腊八节, 除夕 ….
    public let festivals: [String]
    /// 立春 … 大寒, or nil.
    public let solarTerm: String?
    /// Well-known solar-calendar festivals (元旦, 劳动节, 国庆节, 母亲节 …).
    public let solarFestivals: [String]
    /// 丙午.
    public let yearGanZhi: String
    /// 马.
    public let zodiac: String

    static let shownSolarFestivals: [String: String] = [
        "元旦节": "元旦", "情人节": "情人节", "妇女节": "妇女节", "劳动节": "劳动节", "青年节": "青年节",
        "儿童节": "儿童节", "教师节": "教师节", "国庆节": "国庆节", "圣诞节": "圣诞节", "平安夜": "平安夜",
        "母亲节": "母亲节", "父亲节": "父亲节",
    ]

    public init(_ d: YMD) {
        let solar = Solar(year: d.year, month: d.month, day: d.day)
        let lunar = solar.lunar
        monthName = lunar.monthInChinese + "月"
        dayName = lunar.dayInChinese
        festivals = lunar.festivals
        let term = lunar.jieQi
        solarTerm = term.isEmpty ? nil : term
        solarFestivals = (solar.festivals + solar.otherFestivals).compactMap { LunarDay.shownSolarFestivals[$0] }
        yearGanZhi = lunar.yearInGanZhi
        zodiac = lunar.yearShengXiao
    }

    /// The short label under the date: festival > solar term > solar festival > lunar day
    /// (the 1st of a lunar month shows the month's name instead, like paper calendars).
    public var cellLabel: String {
        if let f = festivals.first { return f }
        if let t = solarTerm { return t }
        if let s = solarFestivals.first { return s }
        return dayName == "初一" ? monthName : dayName
    }

    /// 农历十月初五 · 丙午马年
    public var fullDescription: String {
        "农历\(monthName)\(dayName) · \(yearGanZhi)\(zodiac)年"
    }

    /// Extra names worth listing in the day's details (beyond the cell label).
    public var allNames: [String] {
        var seen = Set<String>()
        return (festivals + [solarTerm].compactMap { $0 } + solarFestivals).filter { seen.insert($0).inserted }
    }
}

/// Lunar maths is slow-ish; the calendar grid asks for the same 42 days over and over.
public final class LunarCache: @unchecked Sendable {
    public static let shared = LunarCache()
    private let lock = NSLock()
    private var days: [YMD: LunarDay] = [:]

    public init() {}

    public func day(_ d: YMD) -> LunarDay {
        lock.lock()
        if let cached = days[d] { lock.unlock(); return cached }
        lock.unlock()
        let value = LunarDay(d)
        lock.lock(); days[d] = value; lock.unlock()
        return value
    }
}
