import SwiftUI
import EventKit
import CalendarCore

/// One event row's content, shared by real events and the sample rows in snapshots.
struct EventItem: Identifiable {
    let id: String
    let title: String
    let timeText: String
    let color: Color
    let joinURL: URL?
    let open: () -> Void
}

/// What drops down from the menu bar.
struct PopoverView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var clock = Clock.shared
    @ObservedObject private var events = EventsModel.shared
    private let store = HolidayStore.shared

    /// Rendering to a PNG (Scripts/snapshot.sh): no EventKit, sample events instead.
    var snapshot = false
    var snapshotDay: YMD?

    @State private var shownMonth = YMD(date: Date()).month(offset: 0)
    @State private var selected = YMD(date: Date())
    @State private var adding = false

    private var lang: AppLanguage { settings.language }
    private var today: YMD { snapshotDay ?? YMD(date: clock.now) }
    private func t(_ key: String) -> String { settings.t(key) }

    init(snapshot: Bool = false, snapshotDay: YMD? = nil) {
        self.snapshot = snapshot
        self.snapshotDay = snapshotDay
        if let d = snapshotDay {
            _shownMonth = State(initialValue: d.month(offset: 0))
            _selected = State(initialValue: d)
        }
    }

    var body: some View {
        // Touch these so the view refreshes when data changes.
        let _ = settings.holidayRevision
        let _ = events.revision

        VStack(alignment: .leading, spacing: 10) {
            header
            grid
            Divider()
            detail
            if !settings.colleagues.isEmpty {
                Divider()
                colleagues
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 344)
        // Snapshots add their own flat background; the live window needs an opaque one (see Theme.surface).
        .background(snapshot ? Color.clear : Theme.surface)
        .onAppear {
            if !snapshot {
                jumpToToday()
                events.refreshStatus()
                if events.canAsk { Task { await events.requestAccess() } }
            }
        }
    }

    private func jumpToToday() {
        selected = today
        shownMonth = today.month(offset: 0)
        adding = false
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.monthTitle(shownMonth, lang))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                if settings.lunarVisible {
                    let mid = LunarCache.shared.day(YMD(shownMonth.year, shownMonth.month, 15))
                    Text("\(mid.yearGanZhi)\(mid.zodiac)年")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            IconButton(systemName: "chevron.left") { shownMonth = shownMonth.month(offset: -1) }
            Button(action: jumpToToday) {
                Text(t("today"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .foregroundStyle(Theme.ink)
                    .background(Capsule().fill(Theme.chip))
            }
            .buttonStyle(.plain)
            IconButton(systemName: "chevron.right") { shownMonth = shownMonth.month(offset: 1) }
        }
    }

    // MARK: Grid

    private var grid: some View {
        let days = MonthGrid.days(year: shownMonth.year, month: shownMonth.month, firstWeekday: settings.firstWeekday)
        let eventDays = snapshot ? sampleEventDays(days) : events.daysWithEvents(days, hidden: settings.hiddenCalendarIDs)
        let order = MonthGrid.weekdayOrder(firstWeekday: settings.firstWeekday)
        let headers = Fmt.weekdayHeaders(firstWeekday: settings.firstWeekday, lang)
        return VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    Text(headers[i])
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(order[i] == 1 || order[i] == 7 ? Theme.holiday.opacity(0.8) : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(days, id: \.self) { day in
                    DayCell(day: day,
                            inMonth: day.month == shownMonth.month,
                            isToday: day == today,
                            isSelected: day == selected,
                            info: DayInfoBuilder.info(day, settings: settings, store: store, hasEvents: eventDays.contains(day)))
                        .onTapGesture {
                            selected = day
                            adding = false
                            if day.month != shownMonth.month { shownMonth = day.month(offset: 0) }
                        }
                }
            }
        }
    }

    // MARK: Selected day

    private var detail: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(Fmt.dayTitle(selected, lang))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if settings.lunarVisible {
                    Text(LunarCache.shared.day(selected).fullDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            if settings.lunarVisible {
                let names = LunarCache.shared.day(selected).allNames
                if !names.isEmpty {
                    Text(names.joined(separator: " · "))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.holiday)
                }
            }
            ForEach(Array(DayInfoBuilder.holidayLines(selected, settings: settings, store: store).enumerated()), id: \.offset) { _, line in
                HStack(spacing: 6) {
                    Text(line.region.flag).font(.system(size: 12))
                    Text(line.mark.name(lang))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Spacer()
                    Tag(text: kindText(line.mark.kind), color: kindColor(line.mark.kind, region: line.region))
                }
            }
            if settings.primaryRegion != .us && !store.hasData(settings.primaryRegion, year: selected.year) {
                Text(t("no_data_year")).font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
            }
            eventsSection
        }
    }

    private func kindText(_ kind: HolidayMark.Kind) -> String {
        switch kind {
        case .off: return t("kind_off")
        case .workday: return t("kind_workday")
        case .observance: return t("kind_observance")
        }
    }

    private func kindColor(_ kind: HolidayMark.Kind, region: Region) -> Color {
        switch kind {
        case .off: return region == settings.primaryRegion ? Theme.holiday : Theme.region(region)
        case .workday: return Theme.workday
        case .observance: return Theme.inkSoft
        }
    }

    @ViewBuilder
    private var eventsSection: some View {
        if !snapshot && !events.hasAccess {
            Button {
                if events.canAsk { Task { await events.requestAccess() } } else { events.openPrivacySettings() }
            } label: {
                Label(events.canAsk ? t("grant_calendar") : t("calendar_denied"), systemImage: "calendar.badge.exclamationmark")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        } else {
            let items = snapshot ? sampleItems() : eventItems(selected)
            if items.isEmpty && !adding {
                Text(t("no_events")).font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
            ForEach(items) { item in EventRow(item: item, joinTitle: t("join")) }
            if adding {
                QuickAddView(day: selected, now: clock.now, onDone: { adding = false })
            } else if !snapshot {
                Button { adding = true } label: {
                    Label(t("new_event"), systemImage: "plus")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func eventItems(_ day: YMD) -> [EventItem] {
        events.events(on: day, hidden: settings.hiddenCalendarIDs).enumerated().map { i, e in
            EventItem(id: "\(i)-\(e.calendarItemIdentifier)",
                      title: e.title ?? "",
                      timeText: e.isAllDay ? t("all_day") : "\(Fmt.time(e.startDate))–\(Fmt.time(e.endDate))",
                      color: Color(nsColor: e.calendar?.color ?? .systemGray),
                      joinURL: MeetingLink.find(in: [e.url?.absoluteString, e.location, e.notes]),
                      open: { EventsModel.shared.open(e) })
        }
    }

    // MARK: Colleagues

    private var colleagues: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(t("colleagues")).sectionLabel()
            ForEach(settings.colleagues) { c in
                if let city = c.city, let st = c.status(at: snapshotDay.map { _ in snapshotNow } ?? clock.now, store: store) {
                    HStack(spacing: 6) {
                        Text(city.region?.flag ?? "🌐").font(.system(size: 12))
                        Text(city.name(lang)).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        if st.dayOffset != 0 {
                            Text(st.dayOffset > 0 ? t("tomorrow") : t("yesterday"))
                                .font(.system(size: 10.5))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Text(st.timeString)
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.ink)
                        statusTag(st.state)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func statusTag(_ state: ColleagueStatus.State) -> some View {
        switch state {
        case .working: return Tag(text: t("working"), color: Theme.working)
        case .offHours: return Tag(text: t("off_hours"))
        case .weekend: return Tag(text: t("weekend"))
        case .holiday(let mark): return Tag(text: mark.name(lang), color: Theme.region(mark.region))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 4) {
            Text(countdownText)
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            Spacer()
            IconButton(systemName: "calendar", help: t("open_calendar")) { EventsModel.shared.openCalendarApp() }
            IconButton(systemName: "gearshape", help: t("settings")) { SettingsWindow.show() }
            IconButton(systemName: "power", help: t("quit")) { NSApp.terminate(nil) }
        }
    }

    private var countdownText: String {
        let region = settings.primaryRegion
        if let todayOff = store.marks(on: today, region: region).first(where: { $0.kind == .off }) {
            return String(format: t("countdown_today"), todayOff.name(lang))
        }
        guard let next = store.nextHoliday(after: today, region: region) else { return "" }
        return Fmt.countdown(next.mark.name(lang), days: today.days(until: next.day), lang)
    }

    // MARK: Snapshot samples

    private var snapshotNow: Date {
        // 10:30 on the snapshot day, local time.
        (snapshotDay ?? today).start().addingTimeInterval(10.5 * 3600)
    }

    private func sampleEventDays(_ days: [YMD]) -> Set<YMD> {
        Set(days.filter { !$0.isWeekend && ($0.day % 3 == 0 || $0 == today) })
    }

    private func sampleItems() -> [EventItem] {
        let titles: [AppLanguage: [String]] = [
            .zh: ["产品周会", "和东京团队对齐", "牙医"],
            .en: ["Weekly product sync", "Align with Tokyo team", "Dentist"],
            .ja: ["プロダクト定例", "東京チームと打ち合わせ", "歯医者"],
        ]
        let names = titles[lang] ?? titles[.en]!
        return [
            EventItem(id: "a", title: names[0], timeText: "10:00–11:00", color: .blue,
                      joinURL: URL(string: "https://meet.google.com/abc"), open: {}),
            EventItem(id: "b", title: names[1], timeText: "16:00–16:30", color: .purple,
                      joinURL: URL(string: "https://zoom.us/j/1"), open: {}),
            EventItem(id: "c", title: names[2], timeText: "18:30–19:30", color: .orange, joinURL: nil, open: {}),
        ]
    }
}

struct DayCell: View {
    let day: YMD
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let info: DayInfo
    @State private var hover = false

    var body: some View {
        VStack(spacing: 0) {
            Text("\(day.day)")
                .font(.system(size: 13.5, weight: isToday ? .bold : .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(numberColor)
            Text(info.subtitle.isEmpty ? " " : info.subtitle)
                .font(.system(size: 8.5, weight: info.subtitleIsSpecial ? .semibold : .regular))
                .foregroundStyle(subtitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .padding(.horizontal, 1)
            HStack(spacing: 2) {
                ForEach(Array(info.dots.enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 4, height: 4)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isToday ? Theme.accent : (isSelected ? Theme.chip : (hover ? Theme.chip.opacity(0.5) : .clear)))
        )
        .overlay(alignment: .topTrailing) {
            if let badge = info.badge, badge.text.isEmpty {
                Circle().fill(badge.color).frame(width: 5, height: 5).offset(x: -4, y: 4)
            } else if let badge = info.badge {
                Text(badge.text)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 2.5)
                    .padding(.vertical, 0.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(badge.color))
                    .offset(x: -1.5, y: 1.5)
            }
        }
        .opacity(inMonth ? 1 : 0.38)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }

    private var numberColor: Color {
        if isToday { return Theme.onAccent }
        return info.isOff ? Theme.holiday : Theme.ink
    }

    private var subtitleColor: Color {
        if isToday { return Theme.onAccent.opacity(0.75) }
        return info.subtitleIsSpecial ? Theme.holiday : Theme.inkSoft
    }
}

struct EventRow: View {
    let item: EventItem
    let joinTitle: String
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(item.timeText)
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 4)
            if let url = item.joinURL {
                AccentButton(title: joinTitle) { NSWorkspace.shared.open(url) }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Theme.chip.opacity(0.6) : .clear))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: item.open)
    }
}

/// Inline "new event" form, saved to the default calendar.
struct QuickAddView: View {
    let day: YMD
    let onDone: () -> Void
    @ObservedObject private var settings = AppSettings.shared
    @State private var title = ""
    @State private var time: Date
    @State private var allDay = false
    @State private var error: String?
    @FocusState private var focused: Bool

    init(day: YMD, now: Date, onDone: @escaping () -> Void) {
        self.day = day
        self.onDone = onDone
        // Today: the next whole hour. Other days: 09:00.
        let start: Date
        if day == YMD(date: now) {
            start = Date(timeIntervalSince1970: ((now.timeIntervalSince1970 / 3600).rounded(.down) + 1) * 3600)
        } else {
            start = day.start().addingTimeInterval(9 * 3600)
        }
        _time = State(initialValue: start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(settings.t("title_placeholder"), text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
            HStack(spacing: 8) {
                Toggle(settings.t("all_day"), isOn: $allDay).toggleStyle(.checkbox).font(.system(size: 11.5))
                if !allDay {
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.field)
                        .frame(width: 70)
                }
                Spacer()
                Button(settings.t("cancel"), action: onDone).buttonStyle(.plain).font(.system(size: 11.5)).foregroundStyle(Theme.inkSoft)
                AccentButton(title: settings.t("save"), disabled: title.trimmingCharacters(in: .whitespaces).isEmpty, action: save)
            }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Theme.holiday)
            }
        }
        .onAppear { focused = true }
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Keep the picked time of day but on the selected date.
        var cal = Calendar.current
        cal.timeZone = .current
        let hm = cal.dateComponents([.hour, .minute], from: time)
        let start = allDay ? day.start() : day.start().addingTimeInterval(Double((hm.hour ?? 9) * 3600 + (hm.minute ?? 0) * 60))
        do {
            try EventsModel.shared.addEvent(title: name, start: start, allDay: allDay)
            onDone()
        } catch {
            self.error = String(format: settings.t("save_failed"), error.localizedDescription)
        }
    }
}
