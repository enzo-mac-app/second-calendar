import Foundation
import AppKit
import Sparkle

/// Auto-update through Sparkle (MIT).
///
/// The feed address (`SUFeedURL`) and the public key that update archives must be signed with
/// (`SUPublicEDKey`) are written into Info.plist by `Scripts/make-app.sh`. Without a key, or
/// when the app runs outside a bundle (`swift run`), the updater stays off: Sparkle refuses
/// unsigned updates, and checking would only fail.
///
/// What a check sends: a plain request for the feed. No system profile, no identifiers.
@MainActor
final class Updater: NSObject, ObservableObject {
    static let shared = Updater()

    private var controller: SPUStandardUpdaterController?
    @Published private(set) var canCheck = false

    static var isConfigured: Bool {
        let info = Bundle.main.infoDictionary ?? [:]
        guard Bundle.main.bundleURL.pathExtension == "app",
              let key = info["SUPublicEDKey"] as? String, !key.isEmpty,
              let feed = info["SUFeedURL"] as? String, !feed.isEmpty else { return false }
        return true
    }

    func start() {
        guard controller == nil, Self.isConfigured else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        controller.updater.publisher(for: \.canCheckForUpdates).receive(on: RunLoop.main).assign(to: &$canCheck)
    }

    func checkForUpdates() {
        // A menu bar app has no active window; bring the update dialog to the front.
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(nil)
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }
}
