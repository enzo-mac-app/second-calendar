import Foundation

/// A country whose public holidays we know.
public enum Region: String, CaseIterable, Codable, Sendable, Identifiable {
    case cn, us, jp

    public var id: String { rawValue }

    public var flag: String {
        switch self {
        case .cn: return "🇨🇳"
        case .us: return "🇺🇸"
        case .jp: return "🇯🇵"
        }
    }

    public var defaultTimeZoneID: String {
        switch self {
        case .cn: return "Asia/Shanghai"
        case .us: return "America/New_York"
        case .jp: return "Asia/Tokyo"
        }
    }

    public func name(_ lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.cn, .zh): return "中国"
        case (.cn, .en): return "China"
        case (.cn, .ja): return "中国"
        case (.us, .zh): return "美国"
        case (.us, .en): return "United States"
        case (.us, .ja): return "アメリカ"
        case (.jp, .zh): return "日本"
        case (.jp, .en): return "Japan"
        case (.jp, .ja): return "日本"
        }
    }
}

/// The interface language, switched inside the app.
public enum AppLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case zh, en, ja

    public var id: String { rawValue }

    public var locale: Locale {
        switch self {
        case .zh: return Locale(identifier: "zh_CN")
        case .en: return Locale(identifier: "en_US")
        case .ja: return Locale(identifier: "ja_JP")
        }
    }

    public var nativeName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        case .ja: return "日本語"
        }
    }

    /// Switching language switches the main calendar to this country.
    public var defaultRegion: Region {
        switch self {
        case .zh: return .cn
        case .en: return .us
        case .ja: return .jp
        }
    }

    public static func fromSystem(_ preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        let first = preferred.first?.lowercased() ?? "en"
        if first.hasPrefix("zh") { return .zh }
        if first.hasPrefix("ja") { return .ja }
        return .en
    }
}
