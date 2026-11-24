import Foundation

/// A calendar day with no time and no time zone. All holiday and lunar maths works on these.
public struct YMD: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ year: Int, _ month: Int, _ day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `timeZone`.
    public init(date: Date, timeZone: TimeZone = .current) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.init(c.year!, c.month!, c.day!)
    }

    /// "2026-11-23" or "2026/11/23".
    public init?(iso: String) {
        let parts = iso.split(whereSeparator: { $0 == "-" || $0 == "/" }).compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        self.init(parts[0], parts[1], parts[2])
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (a: YMD, b: YMD) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Noon UTC on this day: a stable instant for weekday and day-count maths.
    var utcNoon: Date {
        YMD.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    /// 1 = Sunday … 7 = Saturday.
    public var weekday: Int { YMD.utc.component(.weekday, from: utcNoon) }
    public var isWeekend: Bool { weekday == 1 || weekday == 7 }

    public func adding(days: Int) -> YMD {
        YMD(date: YMD.utc.date(byAdding: .day, value: days, to: utcNoon)!, timeZone: YMD.utc.timeZone)
    }

    /// Whole days from self to `other` (negative if `other` is earlier).
    public func days(until other: YMD) -> Int {
        YMD.utc.dateComponents([.day], from: utcNoon, to: other.utcNoon).day!
    }

    /// Midnight at the start of this day in `timeZone`.
    public func start(in timeZone: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Noon on this day in `timeZone`: safe to hand to date formatters.
    public func noon(in timeZone: TimeZone = .current) -> Date {
        start(in: timeZone).addingTimeInterval(12 * 3600)
    }

    public static func daysInMonth(year: Int, month: Int) -> Int {
        let d = YMD(year, month, 1).utcNoon
        return YMD.utc.range(of: .day, in: .month, for: d)!.count
    }

    /// The first day of the month `offset` months away.
    public func month(offset: Int) -> YMD {
        let total = year * 12 + (month - 1) + offset
        return YMD(total / 12, total % 12 + 1, 1)
    }
}
