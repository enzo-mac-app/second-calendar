import Foundation

/// All holiday knowledge in one place: the data compiled into the app, overlaid with any newer
/// files HolidayUpdater has downloaded into the cache folder.
public final class HolidayStore: @unchecked Sendable {
    public static let shared = HolidayStore()

    private let lock = NSLock()
    private var cn: [YMD: [HolidayMark]] = [:]
    private var cnYears: Set<Int> = []
    private var jp: [YMD: [HolidayMark]] = [:]
    private var us: [Int: [YMD: [HolidayMark]]] = [:]
    public let cacheDirectory: URL?

    public static var defaultCacheDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SecondCalendar/holidays", isDirectory: true)
    }

    public init(cacheDirectory: URL? = HolidayStore.defaultCacheDirectory, loadBundled: Bool = true) {
        self.cacheDirectory = cacheDirectory
        if loadBundled { reload() }
    }

    /// Bundled data first, then whatever is in the cache (newer files win, year by year).
    public func reload() {
        for (_, json) in BundledHolidays.cn.sorted(by: { $0.key < $1.key }) {
            _ = try? loadCN(json: Data(json.utf8))
        }
        loadJP(csv: BundledHolidays.jpCSV)
        guard let dir = cacheDirectory,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = url.lastPathComponent
            if name.hasPrefix("cn-"), name.hasSuffix(".json"), let data = try? Data(contentsOf: url) {
                _ = try? loadCN(json: data)
            } else if name == "jp.csv", let text = try? String(contentsOf: url, encoding: .utf8) {
                loadJP(csv: text)
            }
        }
    }

    /// Replaces one year of China's data. Returns the year.
    @discardableResult
    public func loadCN(json: Data) throws -> Int {
        let parsed = try CNHolidays.parse(json)
        lock.lock(); defer { lock.unlock() }
        cn = cn.filter { $0.key.year != parsed.year }
        cn.merge(parsed.marks) { _, new in new }
        cnYears.insert(parsed.year)
        return parsed.year
    }

    /// Replaces every year the CSV covers.
    public func loadJP(csv: String) {
        let parsed = JPHolidays.parse(csv: csv)
        guard !parsed.isEmpty else { return }
        let years = Set(parsed.keys.map(\.year))
        lock.lock(); defer { lock.unlock() }
        jp = jp.filter { !years.contains($0.key.year) }
        jp.merge(parsed) { _, new in new }
    }

    public func marks(on day: YMD, region: Region) -> [HolidayMark] {
        switch region {
        case .cn:
            lock.lock(); defer { lock.unlock() }
            return cn[day] ?? []
        case .jp:
            lock.lock(); defer { lock.unlock() }
            return jp[day] ?? []
        case .us:
            return usMarks(year: day.year)[day] ?? []
        }
    }

    /// US marks for a year, including a New Year's Day observed on Dec 31 of the year before.
    private func usMarks(year: Int) -> [YMD: [HolidayMark]] {
        lock.lock()
        if let cached = us[year] { lock.unlock(); return cached }
        lock.unlock()
        var all = USHolidays.marks(year: year)
        for (day, marks) in USHolidays.marks(year: year + 1) where day.year == year {
            all[day, default: []].append(contentsOf: marks)
        }
        all = all.filter { $0.key.year == year }
        lock.lock(); us[year] = all; lock.unlock()
        return all
    }

    /// A day off: a holiday, or a weekend that isn't a make-up workday.
    public func isOffDay(_ day: YMD, region: Region) -> Bool {
        let m = marks(on: day, region: region)
        if m.contains(where: { $0.kind == .workday }) { return false }
        if m.contains(where: { $0.kind == .off }) { return true }
        return day.isWeekend
    }

    /// The years we have data for. The US is computed, so any year works.
    public func coveredYears(_ region: Region) -> ClosedRange<Int>? {
        let years: [Int]
        switch region {
        case .cn:
            lock.lock(); years = Array(cnYears); lock.unlock()
        case .jp:
            lock.lock(); years = jp.keys.map(\.year); lock.unlock()
        case .us:
            return nil
        }
        guard let lo = years.min(), let hi = years.max() else { return nil }
        return lo...hi
    }

    public func hasData(_ region: Region, year: Int) -> Bool {
        guard region != .us else { return true }
        return coveredYears(region)?.contains(year) ?? false
    }

    /// The first day after `day` where a new holiday starts (skips the rest of a holiday you're in).
    public func nextHoliday(after day: YMD, region: Region, within limit: Int = 400) -> (day: YMD, mark: HolidayMark)? {
        var previous = marks(on: day, region: region).filter { $0.kind == .off }.map(\.sourceName)
        var d = day
        for _ in 0..<limit {
            d = d.adding(days: 1)
            let offs = marks(on: d, region: region).filter { $0.kind == .off }
            if let first = offs.first(where: { !previous.contains($0.sourceName) }) {
                return (d, first)
            }
            previous = offs.map(\.sourceName)
        }
        return nil
    }
}
