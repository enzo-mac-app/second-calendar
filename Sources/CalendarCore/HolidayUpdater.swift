import Foundation

/// Downloads newer holiday files into the store's cache folder. China publishes next year's
/// 调休 schedule around November; Japan's Cabinet Office updates its CSV a year or so ahead.
public enum HolidayUpdater {
    static func cnURLs(year: Int) -> [URL] {
        [
            // jsDelivr mirrors GitHub and is reachable from mainland China.
            URL(string: "https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/\(year).json")!,
            URL(string: "https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/\(year).json")!,
        ]
    }

    static let jpURL = URL(string: "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv")!

    /// Returns a line per source saying what happened.
    @discardableResult
    public static func refresh(store: HolidayStore = .shared, years: [Int], session: URLSession = .shared) async -> [String] {
        guard let dir = store.cacheDirectory else { return ["no cache folder"] }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var log: [String] = []

        for year in years {
            var done = false
            for url in cnURLs(year: year) where !done {
                guard let data = try? await fetch(url, session: session) else { continue }
                // Only keep files that parse and actually list days.
                guard let parsed = try? CNHolidays.parse(data), parsed.year == year, !parsed.marks.isEmpty else { continue }
                try? data.write(to: dir.appendingPathComponent("cn-\(year).json"), options: .atomic)
                _ = try? store.loadCN(json: data)
                log.append("cn \(year): \(parsed.marks.count) days")
                done = true
            }
            if !done { log.append("cn \(year): not published yet or unreachable") }
        }

        if let data = try? await fetch(jpURL, session: session), let text = JPHolidays.decode(data) {
            let parsed = JPHolidays.parse(csv: text)
            if parsed.count > 100 {
                try? text.write(to: dir.appendingPathComponent("jp.csv"), atomically: true, encoding: .utf8)
                store.loadJP(csv: text)
                log.append("jp: through \(parsed.keys.map(\.year).max() ?? 0)")
            }
        } else {
            log.append("jp: unreachable")
        }
        return log
    }

    private static func fetch(_ url: URL, session: URLSession) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("SecondCalendar", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }
}
