import Foundation

/// Every address the app points at, in one place. Change them here and nowhere else.
enum AppConfig {
    static let appName = "Second Calendar"
    static let bundleID = "app.enzomac.secondcalendar"
    static let website = URL(string: "https://enzomac.app/secondcalendar/?ref=app-settings")!
    static let sourceCode = URL(string: "https://github.com/enzo-mac-app/second-calendar")!
    static let issues = URL(string: "https://github.com/enzo-mac-app/second-calendar/issues")!
    static let privacyPolicy = URL(string: "https://enzomac.app/privacy/")!
    static let supportEmail = "support@enzomac.app"

    /// Where Sparkle looks for updates. `Scripts/make-app.sh` writes the same address into
    /// Info.plist as SUFeedURL. It ships inside every copy, so it must not change after 1.0.
    static let updateFeed = URL(string: "https://enzomac.app/secondcalendar/appcast.xml")!

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    static var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }
}
