import AppKit
import EventKit
import CalendarCore

/// Reads (and adds) events through the macOS Calendar database, so every account added in
/// System Settings (iCloud, Google, Outlook, Exchange …) shows up without any sign-in here.
@MainActor
final class EventsModel: ObservableObject {
    static let shared = EventsModel()
    let store = EKEventStore()
    @Published private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    /// Bumped whenever the calendar database changes, so views re-read.
    @Published private(set) var revision = 0

    private init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            Task { @MainActor in EventsModel.shared.revision += 1 }
        }
    }

    /// Re-reads the permission (it may have been changed in System Settings meanwhile).
    func refreshStatus() {
        let now = EKEventStore.authorizationStatus(for: .event)
        if now != status {
            status = now
            store.reset()
            revision += 1
        }
    }

    var hasAccess: Bool { status == .fullAccess }
    var canAsk: Bool { status == .notDetermined }

    func requestAccess() async {
        _ = try? await store.requestFullAccessToEvents()
        status = EKEventStore.authorizationStatus(for: .event)
        store.reset()
        revision += 1
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func calendars() -> [EKCalendar] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event).sorted {
            ($0.source.title, $0.title) < ($1.source.title, $1.title)
        }
    }

    private func visibleCalendars(hidden: Set<String>) -> [EKCalendar]? {
        let cals = calendars().filter { !hidden.contains($0.calendarIdentifier) }
        return cals.isEmpty ? nil : cals
    }

    func events(on day: YMD, hidden: Set<String>) -> [EKEvent] {
        guard hasAccess, let cals = visibleCalendars(hidden: hidden) else { return [] }
        let start = day.start()
        let end = day.adding(days: 1).start()
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: cals)
        return store.events(matching: predicate).sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            return $0.startDate < $1.startDate
        }
    }

    /// Which of `days` have at least one event (one query for the whole grid).
    func daysWithEvents(_ days: [YMD], hidden: Set<String>) -> Set<YMD> {
        guard hasAccess, let first = days.first, let last = days.last,
              let cals = visibleCalendars(hidden: hidden) else { return [] }
        let predicate = store.predicateForEvents(withStart: first.start(), end: last.adding(days: 1).start(), calendars: cals)
        var out = Set<YMD>()
        for event in store.events(matching: predicate) {
            var d = YMD(date: event.startDate)
            // An event ending exactly at midnight doesn't touch the next day.
            let endDay = YMD(date: event.endDate.addingTimeInterval(-1))
            var guardCount = 0
            while d <= endDay && guardCount < 62 {
                out.insert(d)
                d = d.adding(days: 1)
                guardCount += 1
            }
        }
        return out
    }

    func addEvent(title: String, start: Date, allDay: Bool) throws {
        let event = EKEvent(eventStore: store)
        event.title = title
        event.isAllDay = allDay
        event.startDate = start
        event.endDate = allDay ? start : start.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent, commit: true)
        revision += 1
    }

    func open(_ event: EKEvent) {
        if let id = event.calendarItemIdentifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "ical://ekevent/\(id)?method=show&options=more"),
           NSWorkspace.shared.open(url) {
            return
        }
        openCalendarApp()
    }

    func openCalendarApp() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Calendar.app"),
                                           configuration: NSWorkspace.OpenConfiguration())
    }
}
