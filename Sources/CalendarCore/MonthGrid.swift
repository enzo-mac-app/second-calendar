import Foundation

public enum MonthGrid {
    /// Six weeks (42 days) covering the month, starting on `firstWeekday` (1 = Sunday, 2 = Monday).
    public static func days(year: Int, month: Int, firstWeekday: Int) -> [YMD] {
        let first = YMD(year, month, 1)
        let lead = (first.weekday - firstWeekday + 7) % 7
        let start = first.adding(days: -lead)
        return (0..<42).map { start.adding(days: $0) }
    }

    /// Weekday numbers (1 = Sunday) in display order.
    public static func weekdayOrder(firstWeekday: Int) -> [Int] {
        (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
    }
}

/// Finds a video-call link in an event's URL, location or notes.
public enum MeetingLink {
    static let hosts = [
        "zoom.us/j/", "zoom.us/my/", "zoom.us/s/", "meet.google.com/", "teams.microsoft.com/l/meetup-join",
        "teams.live.com/meet", "webex.com/", "meeting.tencent.com/", "voovmeeting.com/", "vc.feishu.cn/j/",
        "larksuite.com/", "meeting.dingtalk.com", "facetime.apple.com/join", "whereby.com/", "chime.aws/",
        "gotomeeting.com/join", "around.co/",
    ]

    public static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, range: range) {
                guard let url = match.url, url.scheme?.hasPrefix("http") == true else { continue }
                let s = url.absoluteString.lowercased()
                if hosts.contains(where: { s.contains($0) }) { return url }
            }
        }
        return nil
    }
}
