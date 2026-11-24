import SwiftUI
import CalendarCore

/// Everything the user can change, saved in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var language: AppLanguage { didSet { save("language", language.rawValue) } }
    @Published var primaryRegion: Region { didSet { save("primaryRegion", primaryRegion.rawValue) } }
    @Published var overlayRegions: Set<Region> { didSet { save("overlayRegions", overlayRegions.map(\.rawValue).sorted()) } }
    @Published var showLunar: Bool { didSet { save("showLunar", showLunar) } }
    /// 1 = Sunday, 2 = Monday.
    @Published var firstWeekday: Int { didSet { save("firstWeekday", firstWeekday) } }
    @Published var labelDate: Bool { didSet { save("labelDate", labelDate) } }
    @Published var labelWeekday: Bool { didSet { save("labelWeekday", labelWeekday) } }
    @Published var labelLunar: Bool { didSet { save("labelLunar", labelLunar) } }
    @Published var labelTime: Bool { didSet { save("labelTime", labelTime) } }
    @Published var colleagues: [Colleague] {
        didSet { if let data = try? JSONEncoder().encode(colleagues) { save("colleagues", data) } }
    }
    @Published var hiddenCalendarIDs: Set<String> { didSet { save("hiddenCalendarIDs", hiddenCalendarIDs.sorted()) } }
    @Published var holidayReminders: Bool { didSet { save("holidayReminders", holidayReminders) } }
    /// Bumped after new holiday data is downloaded (not saved).
    @Published var holidayRevision = 0

    private init() {
        let d = UserDefaults.standard
        let lang = d.string(forKey: "language").flatMap(AppLanguage.init(rawValue:)) ?? .fromSystem()
        language = lang
        let primary = d.string(forKey: "primaryRegion").flatMap(Region.init(rawValue:)) ?? lang.defaultRegion
        primaryRegion = primary
        if let stored = d.stringArray(forKey: "overlayRegions") {
            overlayRegions = Set(stored.compactMap(Region.init(rawValue:)))
        } else {
            overlayRegions = Set(Region.allCases).subtracting([primary])
        }
        showLunar = d.object(forKey: "showLunar") as? Bool ?? true
        firstWeekday = d.object(forKey: "firstWeekday") as? Int ?? (lang == .zh ? 2 : 1)
        labelDate = d.object(forKey: "labelDate") as? Bool ?? true
        labelWeekday = d.object(forKey: "labelWeekday") as? Bool ?? true
        labelLunar = d.object(forKey: "labelLunar") as? Bool ?? true
        labelTime = d.object(forKey: "labelTime") as? Bool ?? false
        if let data = d.data(forKey: "colleagues"), let list = try? JSONDecoder().decode([Colleague].self, from: data) {
            colleagues = list
        } else {
            colleagues = Colleague.defaults
        }
        hiddenCalendarIDs = Set(d.stringArray(forKey: "hiddenCalendarIDs") ?? [])
        holidayReminders = d.object(forKey: "holidayReminders") as? Bool ?? true
    }

    private func save(_ key: String, _ value: Any) { defaults.set(value, forKey: key) }

    /// Switching language also switches the main calendar to that country; the other two
    /// stay marked as colleague holidays.
    func switchLanguage(to lang: AppLanguage) {
        guard lang != language else { return }
        language = lang
        primaryRegion = lang.defaultRegion
        overlayRegions = Set(Region.allCases).subtracting([lang.defaultRegion])
    }

    func setPrimary(_ region: Region) {
        primaryRegion = region
        overlayRegions.remove(region)
    }

    /// Lunar dates only make sense on the Chinese calendar.
    var lunarVisible: Bool { primaryRegion == .cn && showLunar }

    func t(_ key: String) -> String { L10n.t(key, language) }
}
