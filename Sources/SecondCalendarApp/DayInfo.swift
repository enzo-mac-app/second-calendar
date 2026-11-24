import SwiftUI
import CalendarCore

/// What one grid cell shows.
struct DayInfo {
    var subtitle = ""
    /// Festival, solar term or holiday name (drawn in the holiday colour).
    var subtitleIsSpecial = false
    /// A day off on the main calendar (holiday, or a weekend that isn't a make-up workday).
    var isOff = false
    var badge: (text: String, color: Color)?
    var dots: [Color] = []
}

@MainActor
enum DayInfoBuilder {
    static func info(_ day: YMD, settings: AppSettings, store: HolidayStore, hasEvents: Bool) -> DayInfo {
        let lang = settings.language
        let primary = settings.primaryRegion
        let marks = store.marks(on: day, region: primary)
        let off = marks.first { $0.kind == .off }
        let work = marks.first { $0.kind == .workday }
        let observance = marks.first { $0.kind == .observance }

        var info = DayInfo()
        if settings.lunarVisible {
            let lunar = LunarCache.shared.day(day)
            info.subtitle = lunar.cellLabel
            info.subtitleIsSpecial = !lunar.festivals.isEmpty || lunar.solarTerm != nil || !lunar.solarFestivals.isEmpty
        } else if let m = off ?? observance {
            info.subtitle = m.shortName(lang)
            info.subtitleIsSpecial = m.kind == .off
        }
        info.isOff = store.isOffDay(day, region: primary)
        if off != nil {
            info.badge = (offBadge(primary, lang), Theme.holiday)
        } else if work != nil {
            info.badge = (workBadge(lang), Theme.workday)
        }
        info.dots = Region.allCases
            .filter { settings.overlayRegions.contains($0) && $0 != primary }
            .filter { r in store.marks(on: day, region: r).contains { $0.kind == .off } }
            .map(Theme.region)
        if hasEvents { info.dots.append(Theme.inkSoft) }
        return info
    }

    /// Empty means "draw a dot" (English words don't fit in the corner).
    static func offBadge(_ region: Region, _ lang: AppLanguage) -> String {
        switch lang {
        case .en: return ""
        case .ja: return region == .jp ? "祝" : "休"
        case .zh: return "休"
        }
    }

    static func workBadge(_ lang: AppLanguage) -> String {
        switch lang {
        case .zh: return "班"
        case .en: return "W"
        case .ja: return "出"
        }
    }

    /// The holiday lines under the selected day: the main calendar first (everything it says),
    /// then colleague countries (days off only).
    static func holidayLines(_ day: YMD, settings: AppSettings, store: HolidayStore) -> [(region: Region, mark: HolidayMark)] {
        var out = store.marks(on: day, region: settings.primaryRegion).map { (settings.primaryRegion, $0) }
        for r in Region.allCases where r != settings.primaryRegion && settings.overlayRegions.contains(r) {
            out += store.marks(on: day, region: r).filter { $0.kind == .off }.map { (r, $0) }
        }
        return out
    }
}
