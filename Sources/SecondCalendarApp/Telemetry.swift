import Foundation
import EventKit
import CalendarCore

/// Anonymous usage counts, so we can see how many downloads turn into people who keep the app.
/// Sent to Enzomac's own Umami (the same statistics the website uses), described in the privacy
/// policy and the README, and off in Settings → General → Share anonymous usage statistics.
///
/// What an event carries: its name, the app version, the macOS major version, a random install id
/// made on first launch, and a few short settings: the app language, the main calendar's country,
/// whether calendar access was granted, and a rough number of colleague cities ("0", "1-2", "3-5",
/// "6+"). Never an event, a calendar name, a city name, a Mac name or anything you typed.
///
/// Two events only: `first_open` (the very first launch) and `open` (at most once a day).
/// Fire and forget: no retries, nothing queued on disk. Sends only from a real .app, not from
/// `swift run`, tests or `--snapshot`. `SECONDCAL_TELEMETRY=0` turns it off, `=1` forces it on.
@MainActor
enum Telemetry {
    static let enabledKey = "shareUsageStatistics"
    private static let installIDKey = "telemetryInstallID"
    private static let lastOpenDayKey = "telemetryLastOpenDay"
    private static let endpoint = URL(string: "https://umani.fastscribe.org/api/send")!
    private static let website = "cc49d179-59e8-47a6-a80a-ca1db8745e67"

    /// On unless the person turned it off.
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    private static var allowedHere: Bool {
        switch ProcessInfo.processInfo.environment["SECONDCAL_TELEMETRY"] {
        case "0": return false
        case "1": return true
        default: return AppConfig.isBundled
        }
    }

    /// Call once per launch.
    static func appLaunched() {
        let defaults = UserDefaults.standard
        let firstTime = defaults.string(forKey: installIDKey) == nil
        _ = installID
        if firstTime { send("first_open") }
        let today = YMD(date: Date())
        let key = "\(today.year)-\(today.month)-\(today.day)"
        if defaults.string(forKey: lastOpenDayKey) != key {
            defaults.set(key, forKey: lastOpenDayKey)
            send("open")
        }
    }

    static func send(_ name: String) {
        guard isEnabled, allowedHere else { return }
        let settings = AppSettings.shared
        let calendar: String = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: "granted"
        case .notDetermined: "not_asked"
        default: "denied"
        }
        let data: [String: Any] = [
            "version": AppConfig.appVersion,
            "macos": String(ProcessInfo.processInfo.operatingSystemVersion.majorVersion),
            "lang": settings.language.rawValue,
            "region": settings.primaryRegion.rawValue,
            "calendar": calendar,
            "colleagues": range(settings.colleagues.count),
        ]
        let body: [String: Any] = [
            "type": "event",
            "payload": [
                "website": website,
                "hostname": "enzomac.app",
                "url": "/secondcalendar/app/\(name)",
                "title": "Second Calendar app",
                "language": Locale.preferredLanguages.first ?? "en-US",
                "screen": "1440x900",
                "name": "app-\(name)",
                "id": installID,
                "data": data,
            ],
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: body) else { return }
        var request = URLRequest(url: endpoint, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = json
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Umami drops requests whose User-Agent looks like a bot.
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) SecondCalendar",
                         forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request).resume()
    }

    private static func range(_ n: Int) -> String {
        switch n { case ...0: "0"; case ...2: "1-2"; case ...5: "3-5"; default: "6+" }
    }

    private static var installID: String {
        if let id = UserDefaults.standard.string(forKey: installIDKey) { return id }
        let id = "sc-" + UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: installIDKey)
        return id
    }
}
