import SwiftUI
import AppKit
import EventKit
import ServiceManagement
import CalendarCore

/// A plain AppKit window: SwiftUI's Settings scene is unreliable for menu-bar-only apps.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = [.preferredContentSize]
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.title = "Second Calendar"
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text(settings.t("general")).tag(0)
                Text(settings.t("calendars")).tag(1)
                Text(settings.t("colleagues")).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.top, 14)
            Group {
                switch tab {
                case 1: CalendarsSettings()
                case 2: ColleaguesSettings()
                default: GeneralSettings()
                }
            }
        }
        .frame(width: 500)
    }
}

private struct GeneralSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var updating = false
    @State private var updateLog = ""
    @AppStorage(Telemetry.enabledKey) private var shareUsage = true
    @ObservedObject private var updater = Updater.shared

    private var lang: AppLanguage { settings.language }
    private func t(_ key: String) -> String { settings.t(key) }

    var body: some View {
        Form {
            Section {
                Picker(t("language"), selection: Binding(get: { settings.language }, set: {
                    settings.switchLanguage(to: $0)
                    Reminders.reschedule()
                })) {
                    ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker(t("primary_region"), selection: Binding(get: { settings.primaryRegion }, set: {
                    settings.setPrimary($0)
                    Reminders.reschedule()
                })) {
                    ForEach(Region.allCases) { Text("\($0.flag) \($0.name(lang))").tag($0) }
                }
                .pickerStyle(.segmented)
                Text(t("primary_hint")).font(.caption).foregroundStyle(.secondary)
                Toggle(t("show_lunar"), isOn: $settings.showLunar)
                    .disabled(settings.primaryRegion != .cn)
            }
            Section(t("overlay")) {
                ForEach(Region.allCases.filter { $0 != settings.primaryRegion }) { r in
                    Toggle(isOn: Binding(get: { settings.overlayRegions.contains(r) }, set: { on in
                        if on { settings.overlayRegions.insert(r) } else { settings.overlayRegions.remove(r) }
                    })) {
                        HStack(spacing: 6) {
                            Circle().fill(Theme.region(r)).frame(width: 8, height: 8)
                            Text("\(r.flag) \(r.name(lang))")
                        }
                    }
                }
            }
            Section {
                Picker(t("week_start"), selection: $settings.firstWeekday) {
                    Text(t("monday")).tag(2)
                    Text(t("sunday")).tag(1)
                }
                .pickerStyle(.segmented)
                LabeledContent(t("menu_bar")) {
                    HStack(spacing: 12) {
                        Toggle(t("label_date"), isOn: $settings.labelDate)
                        Toggle(t("label_weekday"), isOn: $settings.labelWeekday)
                        Toggle(t("label_lunar"), isOn: $settings.labelLunar).disabled(!settings.lunarVisible)
                        Toggle(t("label_time"), isOn: $settings.labelTime)
                    }
                    .toggleStyle(.checkbox)
                }
            }
            Section {
                Toggle(t("launch_at_login"), isOn: Binding(get: { loginEnabled }, set: setLogin))
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Toggle(t("reminders"), isOn: Binding(get: { settings.holidayReminders }, set: {
                    settings.holidayReminders = $0
                    Reminders.reschedule()
                }))
            }
            Section(t("holiday_data")) {
                Text(dataSummary).font(.callout)
                HStack {
                    Button(updating ? t("updating") : t("update_now"), action: updateNow).disabled(updating)
                    Text(updateLog).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Section {
                Toggle(t("share_usage"), isOn: $shareUsage)
                Text(t("share_usage_hint")).font(.caption).foregroundStyle(.secondary)
            }
            Section(t("about")) {
                LabeledContent(t("version"), value: AppConfig.appVersion)
                Text(t("about_line")).font(.callout)
                if Updater.isConfigured {
                    Toggle(t("auto_updates"), isOn: Binding(get: { updater.automaticallyChecks }, set: { updater.automaticallyChecks = $0 }))
                    Button(t("check_updates")) { updater.checkForUpdates() }.disabled(!updater.canCheck)
                }
                HStack(spacing: 14) {
                    Link(t("website"), destination: AppConfig.website)
                    Link(t("source_code"), destination: AppConfig.sourceCode)
                    Link(t("report_issue"), destination: AppConfig.issues)
                    Link(t("privacy"), destination: AppConfig.privacyPolicy)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
        .frame(height: 680)
    }

    private var dataSummary: String {
        let _ = settings.holidayRevision
        let store = HolidayStore.shared
        func range(_ r: Region) -> String {
            guard let y = store.coveredYears(r) else { return "—" }
            return "\(y.lowerBound)–\(y.upperBound)"
        }
        return "🇨🇳 \(range(.cn))    🇯🇵 \(range(.jp))    🇺🇸 \(t("rule_based"))"
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        loginEnabled = SMAppService.mainApp.status == .enabled
    }

    private func updateNow() {
        updating = true
        Task { @MainActor in
            let year = YMD(date: Date()).year
            let log = await HolidayUpdater.refresh(years: [year, year + 1])
            UserDefaults.standard.set(Date(), forKey: "holidayRefreshedAt")
            settings.holidayRevision += 1
            Reminders.reschedule()
            updateLog = log.joined(separator: " · ")
            updating = false
        }
    }
}

private struct CalendarsSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var events = EventsModel.shared

    var body: some View {
        let _ = events.revision
        Form {
            if !events.hasAccess {
                Section {
                    Button(events.canAsk ? settings.t("grant_calendar") : settings.t("calendar_denied")) {
                        if events.canAsk { Task { await events.requestAccess() } } else { events.openPrivacySettings() }
                    }
                }
            } else {
                let groups = Dictionary(grouping: events.calendars(), by: { $0.source.title })
                ForEach(groups.keys.sorted(), id: \.self) { source in
                    Section(source) {
                        ForEach(groups[source] ?? [], id: \.calendarIdentifier) { cal in
                            Toggle(isOn: Binding(get: { !settings.hiddenCalendarIDs.contains(cal.calendarIdentifier) }, set: { on in
                                if on { settings.hiddenCalendarIDs.remove(cal.calendarIdentifier) } else { settings.hiddenCalendarIDs.insert(cal.calendarIdentifier) }
                            })) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(nsColor: cal.color)).frame(width: 9, height: 9)
                                    Text(cal.title)
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 460)
    }
}

private struct ColleaguesSettings: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newCity = "london"

    private var lang: AppLanguage { settings.language }

    var body: some View {
        Form {
            Section {
                Text(settings.t("colleagues_hint")).font(.callout).foregroundStyle(.secondary)
            }
            Section {
                ForEach($settings.colleagues) { $c in
                    HStack(spacing: 6) {
                        Text(c.city?.region?.flag ?? "🌐")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(c.city?.name(lang) ?? c.cityID)
                            if c.city?.region == nil {
                                Text(settings.t("no_holidays_city")).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(settings.t("work_hours")).font(.caption).foregroundStyle(.secondary)
                        Picker("", selection: $c.workStart) {
                            ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0 * 60) }
                        }
                        .labelsHidden()
                        .frame(width: 78)
                        Text("–")
                        Picker("", selection: $c.workEnd) {
                            ForEach(1...24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0 * 60) }
                        }
                        .labelsHidden()
                        .frame(width: 78)
                        Button {
                            settings.colleagues.removeAll { $0.id == c.id }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help(settings.t("remove"))
                    }
                }
            }
            Section {
                HStack {
                    Picker(settings.t("add_colleague"), selection: $newCity) {
                        ForEach(City.all) { Text("\($0.region?.flag ?? "🌐") \($0.name(lang))").tag($0.id) }
                    }
                    Button(settings.t("add_colleague")) {
                        settings.colleagues.append(Colleague(cityID: newCity))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 420)
    }
}
