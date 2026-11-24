import Foundation

/// A city colleagues work in. Picked from a short built-in list so names can follow the app language.
public struct City: Identifiable, Hashable, Sendable {
    public let id: String
    public let timeZoneID: String
    /// Whose holidays apply; nil where we have no holiday data.
    public let region: Region?
    let names: [AppLanguage: String]

    public func name(_ lang: AppLanguage) -> String { names[lang] ?? id }
    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    public static func find(_ id: String) -> City? { all.first { $0.id == id } }

    private static func c(_ id: String, _ tz: String, _ region: Region?, _ zh: String, _ en: String, _ ja: String) -> City {
        City(id: id, timeZoneID: tz, region: region, names: [.zh: zh, .en: en, .ja: ja])
    }

    public static let all: [City] = [
        c("new_york", "America/New_York", .us, "纽约", "New York", "ニューヨーク"),
        c("boston", "America/New_York", .us, "波士顿", "Boston", "ボストン"),
        c("chicago", "America/Chicago", .us, "芝加哥", "Chicago", "シカゴ"),
        c("austin", "America/Chicago", .us, "奥斯汀", "Austin", "オースティン"),
        c("denver", "America/Denver", .us, "丹佛", "Denver", "デンバー"),
        c("los_angeles", "America/Los_Angeles", .us, "洛杉矶", "Los Angeles", "ロサンゼルス"),
        c("san_francisco", "America/Los_Angeles", .us, "旧金山", "San Francisco", "サンフランシスコ"),
        c("seattle", "America/Los_Angeles", .us, "西雅图", "Seattle", "シアトル"),
        c("tokyo", "Asia/Tokyo", .jp, "东京", "Tokyo", "東京"),
        c("osaka", "Asia/Tokyo", .jp, "大阪", "Osaka", "大阪"),
        c("fukuoka", "Asia/Tokyo", .jp, "福冈", "Fukuoka", "福岡"),
        c("beijing", "Asia/Shanghai", .cn, "北京", "Beijing", "北京"),
        c("shanghai", "Asia/Shanghai", .cn, "上海", "Shanghai", "上海"),
        c("shenzhen", "Asia/Shanghai", .cn, "深圳", "Shenzhen", "深圳"),
        c("hangzhou", "Asia/Shanghai", .cn, "杭州", "Hangzhou", "杭州"),
        c("hong_kong", "Asia/Hong_Kong", nil, "香港", "Hong Kong", "香港"),
        c("taipei", "Asia/Taipei", nil, "台北", "Taipei", "台北"),
        c("seoul", "Asia/Seoul", nil, "首尔", "Seoul", "ソウル"),
        c("singapore", "Asia/Singapore", nil, "新加坡", "Singapore", "シンガポール"),
        c("bangalore", "Asia/Kolkata", nil, "班加罗尔", "Bangalore", "ベンガルール"),
        c("dubai", "Asia/Dubai", nil, "迪拜", "Dubai", "ドバイ"),
        c("london", "Europe/London", nil, "伦敦", "London", "ロンドン"),
        c("berlin", "Europe/Berlin", nil, "柏林", "Berlin", "ベルリン"),
        c("paris", "Europe/Paris", nil, "巴黎", "Paris", "パリ"),
        c("amsterdam", "Europe/Amsterdam", nil, "阿姆斯特丹", "Amsterdam", "アムステルダム"),
        c("sydney", "Australia/Sydney", nil, "悉尼", "Sydney", "シドニー"),
        c("toronto", "America/Toronto", nil, "多伦多", "Toronto", "トロント"),
        c("vancouver", "America/Vancouver", nil, "温哥华", "Vancouver", "バンクーバー"),
    ]
}

/// Where a colleague works and when.
public struct Colleague: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var cityID: String
    /// Minutes after local midnight.
    public var workStart: Int
    public var workEnd: Int

    public init(id: UUID = UUID(), cityID: String, workStart: Int = 9 * 60, workEnd: Int = 18 * 60) {
        self.id = id
        self.cityID = cityID
        self.workStart = workStart
        self.workEnd = workEnd
    }

    public var city: City? { City.find(cityID) }

    public static let defaults: [Colleague] = [Colleague(cityID: "new_york"), Colleague(cityID: "tokyo")]
}

public struct ColleagueStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        case working
        case offHours
        case weekend
        case holiday(HolidayMark)
    }

    public let localDay: YMD
    /// Minutes after local midnight.
    public let minutes: Int
    public let state: State
    /// +1 if it's already tomorrow there, -1 if still yesterday.
    public let dayOffset: Int

    public var timeString: String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
}

extension Colleague {
    public func status(at now: Date, store: HolidayStore, myTimeZone: TimeZone = .current) -> ColleagueStatus? {
        guard let city else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = city.timeZone
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let local = YMD(c.year!, c.month!, c.day!)
        let minutes = c.hour! * 60 + c.minute!
        let mine = YMD(date: now, timeZone: myTimeZone)

        let marks = city.region.map { store.marks(on: local, region: $0) } ?? []
        let state: ColleagueStatus.State
        if let off = marks.first(where: { $0.kind == .off }) {
            state = .holiday(off)
        } else if local.isWeekend && !marks.contains(where: { $0.kind == .workday }) {
            state = .weekend
        } else if minutes >= workStart && minutes < workEnd {
            state = .working
        } else {
            state = .offHours
        }
        return ColleagueStatus(localDay: local, minutes: minutes, state: state, dayOffset: mine.days(until: local))
    }
}
