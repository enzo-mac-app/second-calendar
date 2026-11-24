import Foundation
@preconcurrency import UserNotifications
import CalendarCore

/// Notifications at 20:00 the evening before a make-up workday or the first day of a holiday,
/// on the main calendar, for the next 60 days. Rebuilt whenever settings or data change.
@MainActor
enum Reminders {
    static let prefix = "sc-"

    /// UNUserNotificationCenter needs a real app bundle (not `swift run`).
    static var available: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static func reschedule() {
        guard available else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let pending = await center.pendingNotificationRequests()
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            guard AppSettings.shared.holidayReminders else { return }
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            addUpcoming(center)
        }
    }

    private static func addUpcoming(_ center: UNUserNotificationCenter) {
        let settings = AppSettings.shared
        let region = settings.primaryRegion
        let lang = settings.language
        let store = HolidayStore.shared
        let today = YMD(date: Date())
        for i in 1...60 {
            let day = today.adding(days: i)
            let marks = store.marks(on: day, region: region)
            let content = UNMutableNotificationContent()
            if let work = marks.first(where: { $0.kind == .workday }), day.isWeekend {
                content.title = L10n.t("reminder_workday_title", lang)
                content.body = String(format: L10n.t("reminder_workday_body", lang), work.name(lang))
            } else if let off = marks.first(where: { $0.kind == .off }), !store.isOffDay(day.adding(days: -1), region: region) {
                content.title = L10n.t("reminder_holiday_title", lang)
                content.body = off.name(lang)
            } else {
                continue
            }
            content.sound = .default
            let fire = day.adding(days: -1).start().addingTimeInterval(20 * 3600)
            guard fire > Date() else { continue }
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(identifier: "\(prefix)\(day)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            center.add(request)
        }
    }
}

/// Checks for newer holiday files every few days.
@MainActor
enum HolidayRefresh {
    static func runIfDue() async {
        let last = UserDefaults.standard.object(forKey: "holidayRefreshedAt") as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 3 * 24 * 3600 else { return }
        let year = YMD(date: Date()).year
        await HolidayUpdater.refresh(years: [year, year + 1])
        UserDefaults.standard.set(Date(), forKey: "holidayRefreshedAt")
        AppSettings.shared.holidayRevision += 1
        Reminders.reschedule()
    }
}
