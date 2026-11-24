import Foundation

/// One thing a country says about a day: a day off, a make-up workday, or a non-holiday observance.
public struct HolidayMark: Hashable, Sendable {
    public enum Kind: String, Sendable {
        /// A public holiday (or China's bridged days off).
        case off
        /// China's 调休 make-up workday, usually on a weekend.
        case workday
        /// A well-known day that isn't a day off (Mother's Day, Halloween …).
        case observance
    }

    public let region: Region
    public let kind: Kind
    /// The name as the source writes it: Chinese for China, Japanese for Japan, English for the US.
    public let sourceName: String
    /// US only: the weekday a weekend holiday is moved to.
    public let observed: Bool

    public init(region: Region, kind: Kind, sourceName: String, observed: Bool = false) {
        self.region = region
        self.kind = kind
        self.sourceName = sourceName
        self.observed = observed
    }

    public func name(_ lang: AppLanguage) -> String {
        HolidayNames.localized(sourceName, region: region, lang: lang, observed: observed)
    }

    /// A shorter name for the tiny label inside a calendar cell.
    public func shortName(_ lang: AppLanguage) -> String {
        if region == .us, let short = HolidayNames.usShort[sourceName]?[lang] { return short }
        return HolidayNames.localized(sourceName, region: region, lang: lang, observed: false)
    }
}

enum HolidayNames {
    static func localized(_ source: String, region: Region, lang: AppLanguage, observed: Bool) -> String {
        switch region {
        case .cn:
            // holiday-cn joins overlapping holidays with "、" (2025: 国庆节、中秋节).
            let parts = source.split(separator: "、").map { cn[String($0)]?[lang] ?? String($0) }
            return parts.joined(separator: lang == .en ? " & " : "・")
        case .jp:
            return jp[source]?[lang] ?? source
        case .us:
            let base = us[source]?[lang] ?? source
            guard observed else { return base }
            switch lang {
            case .zh: return base + "（补假）"
            case .en: return base + " (observed)"
            case .ja: return base + "（振替）"
            }
        }
    }

    private static func t(_ zh: String, _ en: String, _ ja: String) -> [AppLanguage: String] {
        [.zh: zh, .en: en, .ja: ja]
    }

    static let cn: [String: [AppLanguage: String]] = [
        "元旦": t("元旦", "New Year's Day", "元旦"),
        "春节": t("春节", "Spring Festival", "春節"),
        "清明节": t("清明节", "Qingming Festival", "清明節"),
        "劳动节": t("劳动节", "Labour Day", "労働節"),
        "端午节": t("端午节", "Dragon Boat Festival", "端午節"),
        "中秋节": t("中秋节", "Mid-Autumn Festival", "中秋節"),
        "国庆节": t("国庆节", "National Day", "国慶節"),
    ]

    static let jp: [String: [AppLanguage: String]] = [
        "元日": t("元日", "New Year's Day", "元日"),
        "成人の日": t("成人节", "Coming of Age Day", "成人の日"),
        "建国記念の日": t("建国纪念日", "National Foundation Day", "建国記念の日"),
        "天皇誕生日": t("天皇诞辰", "Emperor's Birthday", "天皇誕生日"),
        "春分の日": t("春分日", "Vernal Equinox Day", "春分の日"),
        "昭和の日": t("昭和日", "Showa Day", "昭和の日"),
        "憲法記念日": t("宪法纪念日", "Constitution Day", "憲法記念日"),
        "みどりの日": t("绿之日", "Greenery Day", "みどりの日"),
        "こどもの日": t("儿童节", "Children's Day", "こどもの日"),
        "海の日": t("海之日", "Marine Day", "海の日"),
        "山の日": t("山之日", "Mountain Day", "山の日"),
        "敬老の日": t("敬老日", "Respect for the Aged Day", "敬老の日"),
        "秋分の日": t("秋分日", "Autumnal Equinox Day", "秋分の日"),
        "スポーツの日": t("体育日", "Sports Day", "スポーツの日"),
        "体育の日": t("体育日", "Sports Day", "体育の日"),
        "文化の日": t("文化日", "Culture Day", "文化の日"),
        "勤労感謝の日": t("勤劳感谢日", "Labour Thanksgiving Day", "勤労感謝の日"),
        // Substitute holidays and days sandwiched between two holidays.
        "休日": t("补休", "Substitute holiday", "休日"),
    ]

    static let usShort: [String: [AppLanguage: String]] = [
        "New Year's Day": t("元旦", "New Year's", "元日"),
        "Martin Luther King Jr. Day": t("马丁路德金日", "MLK Day", "キング牧師"),
        "Presidents' Day": t("总统日", "Presidents'", "大統領の日"),
        "Memorial Day": t("阵亡将士日", "Memorial", "メモリアル"),
        "Independence Day": t("独立日", "July 4th", "独立記念日"),
        "Columbus Day": t("哥伦布日", "Columbus", "コロンブス"),
        "Veterans Day": t("退伍军人节", "Veterans", "退役軍人"),
        "Day after Thanksgiving": t("黑色星期五", "Black Friday", "ブラックフライデー"),
        "Christmas Day": t("圣诞节", "Christmas", "クリスマス"),
        "Valentine's Day": t("情人节", "Valentine's", "バレンタイン"),
        "Christmas Eve": t("平安夜", "Xmas Eve", "イブ"),
        "New Year's Eve": t("跨年夜", "NYE", "大晦日"),
    ]

    static let us: [String: [AppLanguage: String]] = [
        "New Year's Day": t("元旦", "New Year's Day", "元日"),
        "Martin Luther King Jr. Day": t("马丁·路德·金纪念日", "Martin Luther King Jr. Day", "キング牧師記念日"),
        "Presidents' Day": t("总统日", "Presidents' Day", "大統領の日"),
        "Memorial Day": t("阵亡将士纪念日", "Memorial Day", "戦没将兵追悼記念日"),
        "Juneteenth": t("六月节", "Juneteenth", "ジューンティーンス"),
        "Independence Day": t("独立日", "Independence Day", "独立記念日"),
        "Labor Day": t("劳动节", "Labor Day", "レイバー・デー"),
        "Columbus Day": t("哥伦布日", "Columbus Day", "コロンブス・デー"),
        "Veterans Day": t("退伍军人节", "Veterans Day", "退役軍人の日"),
        "Thanksgiving": t("感恩节", "Thanksgiving", "感謝祭"),
        "Day after Thanksgiving": t("感恩节翌日", "Day after Thanksgiving", "感謝祭翌日"),
        "Christmas Day": t("圣诞节", "Christmas Day", "クリスマス"),
        "Valentine's Day": t("情人节", "Valentine's Day", "バレンタインデー"),
        "Mother's Day": t("母亲节", "Mother's Day", "母の日"),
        "Father's Day": t("父亲节", "Father's Day", "父の日"),
        "Halloween": t("万圣节前夜", "Halloween", "ハロウィン"),
        "Christmas Eve": t("平安夜", "Christmas Eve", "クリスマス・イブ"),
        "New Year's Eve": t("跨年夜", "New Year's Eve", "大晦日"),
    ]
}
