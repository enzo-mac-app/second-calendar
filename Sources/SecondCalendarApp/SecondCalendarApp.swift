import SwiftUI
import AppKit
import UserNotifications
import ServiceManagement
import CalendarCore

@main
struct SecondCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

/// The text in the menu bar, e.g. "11月23日 周一 十月初五".
struct MenuBarLabel: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var clock = Clock.shared

    var body: some View {
        let text = MenuBarLabel.text(settings: settings, now: clock.now)
        if text.isEmpty {
            Image(systemName: "calendar")
        } else {
            Text(text)
        }
    }

    @MainActor
    static func text(settings: AppSettings, now: Date) -> String {
        let lang = settings.language
        let today = YMD(date: now)
        var parts: [String] = []
        if settings.labelDate { parts.append(Fmt.shortDate(today, lang)) }
        if settings.labelWeekday { parts.append(Fmt.shortWeekday(today, lang)) }
        if settings.labelLunar && settings.lunarVisible {
            let lunar = LunarCache.shared.day(today)
            parts.append(lunar.monthName + lunar.dayName)
        }
        if settings.labelTime { parts.append(Fmt.time(now)) }
        return parts.joined(separator: " ")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if Snapshot.runIfRequested() { return }
            NSApp.setActivationPolicy(.accessory)
            if Reminders.available { UNUserNotificationCenter.current().delegate = self }
            _ = Clock.shared
            // First run from /Applications: open at login by default (Settings → General to turn off).
            if !UserDefaults.standard.bool(forKey: "didFirstLaunch"), Bundle.main.bundlePath.hasPrefix("/Applications/") {
                UserDefaults.standard.set(true, forKey: "didFirstLaunch")
                try? SMAppService.mainApp.register()
            }
            Reminders.reschedule()
            Updater.shared.start()
            Telemetry.appLaunched()
            Task { await HolidayRefresh.runIfDue() }
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { _ in
                Task { @MainActor in await HolidayRefresh.runIfDue() }
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
