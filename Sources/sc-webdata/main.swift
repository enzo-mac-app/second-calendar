// Exports the calendar data the website's in-browser calendar shows (enzomac.app/secondcalendar/calendar/),
// computed by the same CalendarCore the app uses, so the web page and the app always agree.
//   swift run -c release sc-webdata <out.json>      (Scripts/web-data.sh writes it into the site)
//
// Output, one file:
//   years   [first, last]: the years with China and Japan holiday data (US is computed for the same years)
//   lunar   "YYYY-MM-DD": [cell label, full description, 1 if the label is a festival or solar term, extra names]
//   marks   region → "YYYY-MM-DD": [[kind (off/workday/observance), [name zh, en, ja], [short zh, en, ja]], …]
//   cities  [{id, tz, region, names: [zh, en, ja]}]
import Foundation
import CalendarCore

let out = CommandLine.arguments.dropFirst().first ?? "calendar-data.json"
let store = HolidayStore.shared
let langs: [AppLanguage] = [.zh, .en, .ja]
guard let cn = store.coveredYears(.cn), let jp = store.coveredYears(.jp) else {
    FileHandle.standardError.write("no holiday data\n".data(using: .utf8)!); exit(1)
}
// Lunar years are cheap; show from last year so the page has a past to page back into.
let first = max(cn.lowerBound, jp.lowerBound), last = min(cn.upperBound, jp.upperBound)

func key(_ d: YMD) -> String { String(format: "%04d-%02d-%02d", d.year, d.month, d.day) }

var lunar: [String: [Any]] = [:]
var marks: [String: [String: [[Any]]]] = ["cn": [:], "us": [:], "jp": [:]]
var d = YMD(first, 1, 1)
let end = YMD(last, 12, 31)
while d <= end {
    let l = LunarDay(d)
    let special = !l.festivals.isEmpty || l.solarTerm != nil || !l.solarFestivals.isEmpty
    lunar[key(d)] = [l.cellLabel, l.fullDescription, special ? 1 : 0, l.allNames]
    for r in Region.allCases {
        let m = store.marks(on: d, region: r)
        if !m.isEmpty {
            marks[r.rawValue]![key(d)] = m.map { mark in [mark.kind.rawValue, langs.map { mark.name($0) }, langs.map { mark.shortName($0) }] as [Any] }
        }
    }
    d = d.adding(days: 1)
}
let cities: [[String: Any]] = City.all.map { city in
    var c: [String: Any] = ["id": city.id, "tz": city.timeZoneID, "names": langs.map { city.name($0) }]
    if let r = city.region { c["region"] = r.rawValue }
    return c
}
let json: [String: Any] = ["years": [first, last], "lunar": lunar, "marks": marks, "cities": cities]
let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out): \(first)–\(last), \(data.count / 1024) KB")
