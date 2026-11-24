import AppKit
import Combine

/// Ticks on every minute boundary, and right away after sleep, clock or time-zone changes.
@MainActor
final class Clock: ObservableObject {
    static let shared = Clock()
    @Published private(set) var now = Date()
    private var timer: Timer?

    private init() {
        schedule()
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in Clock.shared.refresh() }
        }
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange, .NSCalendarDayChanged] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in Clock.shared.refresh() }
            }
        }
    }

    func refresh() {
        NSTimeZone.resetSystemTimeZone()
        now = Date()
        schedule()
    }

    private func schedule() {
        timer?.invalidate()
        let next = (Date().timeIntervalSince1970 / 60).rounded(.down) * 60 + 60.05
        let t = Timer(fire: Date(timeIntervalSince1970: next), interval: 60, repeats: true) { _ in
            Task { @MainActor in Clock.shared.now = Date() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }
}
