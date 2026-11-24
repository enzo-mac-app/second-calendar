import Foundation

/// US federal holidays, computed from the rules in 5 U.S.C. 6103 (no data file needed),
/// plus a few well-known days that aren't days off.
public enum USHolidays {
    public static func marks(year: Int) -> [YMD: [HolidayMark]] {
        var out: [YMD: [HolidayMark]] = [:]
        func add(_ d: YMD, _ name: String, _ kind: HolidayMark.Kind = .off, observed: Bool = false) {
            out[d, default: []].append(HolidayMark(region: .us, kind: kind, sourceName: name, observed: observed))
        }
        // Fixed-date holidays move to Friday when they fall on Saturday, Monday when on Sunday.
        func fixed(_ month: Int, _ day: Int, _ name: String) {
            let d = YMD(year, month, day)
            add(d, name)
            if d.weekday == 7 { add(d.adding(days: -1), name, observed: true) }
            if d.weekday == 1 { add(d.adding(days: 1), name, observed: true) }
        }
        fixed(1, 1, "New Year's Day")
        add(nth(year, 1, weekday: 2, n: 3), "Martin Luther King Jr. Day")
        add(nth(year, 2, weekday: 2, n: 3), "Presidents' Day")
        add(last(year, 5, weekday: 2), "Memorial Day")
        fixed(6, 19, "Juneteenth")
        fixed(7, 4, "Independence Day")
        add(nth(year, 9, weekday: 2, n: 1), "Labor Day")
        add(nth(year, 10, weekday: 2, n: 2), "Columbus Day")
        fixed(11, 11, "Veterans Day")
        let thanksgiving = nth(year, 11, weekday: 5, n: 4)
        add(thanksgiving, "Thanksgiving")
        add(thanksgiving.adding(days: 1), "Day after Thanksgiving", .observance)
        fixed(12, 25, "Christmas Day")

        add(YMD(year, 2, 14), "Valentine's Day", .observance)
        add(nth(year, 5, weekday: 1, n: 2), "Mother's Day", .observance)
        add(nth(year, 6, weekday: 1, n: 3), "Father's Day", .observance)
        add(YMD(year, 10, 31), "Halloween", .observance)
        add(YMD(year, 12, 24), "Christmas Eve", .observance)
        add(YMD(year, 12, 31), "New Year's Eve", .observance)
        return out
    }

    /// The n-th `weekday` (1 = Sunday) of a month.
    static func nth(_ year: Int, _ month: Int, weekday: Int, n: Int) -> YMD {
        let first = YMD(year, month, 1)
        let offset = (weekday - first.weekday + 7) % 7
        return YMD(year, month, 1 + offset + 7 * (n - 1))
    }

    /// The last `weekday` (1 = Sunday) of a month.
    static func last(_ year: Int, _ month: Int, weekday: Int) -> YMD {
        let lastDay = YMD(year, month, YMD.daysInMonth(year: year, month: month))
        let offset = (lastDay.weekday - weekday + 7) % 7
        return lastDay.adding(days: -offset)
    }
}

/// China's statutory holidays and 调休 make-up workdays, in the JSON format of
/// github.com/NateScarlet/holiday-cn (scraped from the State Council's yearly notice).
public enum CNHolidays {
    struct File: Decodable {
        struct Day: Decodable {
            let name: String
            let date: String
            let isOffDay: Bool
        }
        let year: Int
        let days: [Day]
    }

    /// Returns the year the file covers and its marks.
    public static func parse(_ data: Data) throws -> (year: Int, marks: [YMD: [HolidayMark]]) {
        let file = try JSONDecoder().decode(File.self, from: data)
        var out: [YMD: [HolidayMark]] = [:]
        for d in file.days {
            guard let day = YMD(iso: d.date) else { continue }
            out[day, default: []].append(HolidayMark(region: .cn, kind: d.isOffDay ? .off : .workday, sourceName: d.name))
        }
        return (file.year, out)
    }
}

/// Japan's national holidays from the Cabinet Office's syukujitsu.csv
/// (https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv), which already includes
/// substitute holidays (振替休日) and sandwiched days (国民の休日), both named 休日.
public enum JPHolidays {
    public static func parse(csv: String) -> [YMD: [HolidayMark]] {
        var out: [YMD: [HolidayMark]] = [:]
        for line in csv.split(whereSeparator: \.isNewline) {
            let cols = line.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count == 2, let day = YMD(iso: cols[0]), !cols[1].isEmpty else { continue }
            out[day, default: []].append(HolidayMark(region: .jp, kind: .off, sourceName: cols[1]))
        }
        return out
    }

    /// The Cabinet Office publishes the file in Shift_JIS.
    public static func decode(_ data: Data) -> String? {
        String(data: data, encoding: .shiftJIS) ?? String(data: data, encoding: .utf8)
    }
}
