import Foundation
import CalendarCore

/// Date text in the app's language (not the system's).
enum Fmt {
    private static var cache: [String: DateFormatter] = [:]

    private static func formatter(_ template: String, _ lang: AppLanguage) -> DateFormatter {
        let key = "\(lang.rawValue)|\(template)|\(TimeZone.current.identifier)"
        if let f = cache[key] { return f }
        let f = DateFormatter()
        f.locale = lang.locale
        f.timeZone = .current
        f.setLocalizedDateFormatFromTemplate(template)
        cache[key] = f
        return f
    }

    /// 2026年11月 / November 2026
    static func monthTitle(_ firstOfMonth: YMD, _ lang: AppLanguage) -> String {
        formatter("yMMMM", lang).string(from: firstOfMonth.noon())
    }

    /// 11月26日 星期四 / Thursday, November 26
    static func dayTitle(_ day: YMD, _ lang: AppLanguage) -> String {
        formatter("MMMMdEEEE", lang).string(from: day.noon())
    }

    /// 11月23日 / Nov 23
    static func shortDate(_ day: YMD, _ lang: AppLanguage) -> String {
        formatter("MMMd", lang).string(from: day.noon())
    }

    /// 周一 / Mon / 月
    static func shortWeekday(_ day: YMD, _ lang: AppLanguage) -> String {
        formatter("EEE", lang).string(from: day.noon())
    }

    static func time(_ date: Date) -> String {
        let f = formatter("HHmm", .zh)
        return f.string(from: date)
    }

    /// Column headings: 一 二 三 … / Sun Mon … / 日 月 火 …, in display order.
    static func weekdayHeaders(firstWeekday: Int, _ lang: AppLanguage) -> [String] {
        let f = DateFormatter()
        f.locale = lang.locale
        let symbols = (lang == .en ? f.shortStandaloneWeekdaySymbols : f.veryShortStandaloneWeekdaySymbols) ?? []
        return MonthGrid.weekdayOrder(firstWeekday: firstWeekday).map { symbols.indices.contains($0 - 1) ? symbols[$0 - 1] : "" }
    }

    /// 距元旦还有 39 天 / 39 days until New Year's Day
    static func countdown(_ name: String, days: Int, _ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return days == 1 ? "明天就是\(name)" : "距\(name)还有 \(days) 天"
        case .en: return days == 1 ? "\(name) is tomorrow" : "\(days) days until \(name)"
        case .ja: return days == 1 ? "明日は\(name)" : "\(name)まであと\(days)日"
        }
    }
}
