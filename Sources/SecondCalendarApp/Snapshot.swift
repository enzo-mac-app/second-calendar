import SwiftUI
import AppKit
import CalendarCore

/// `SecondCalendar --snapshot out.png [--day 2026-10-01]` renders the drop-down to a PNG and quits.
/// Language etc. come from the usual settings, which can be overridden per run with
/// `-language en -primaryRegion us` (UserDefaults argument domain, never saved).
/// Used by Scripts/snapshot.sh for docs/ui/ and to check layout without clicking the menu bar.
@MainActor
enum Snapshot {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return false }
        let out = URL(fileURLWithPath: args[i + 1])
        var day = YMD(date: Date())
        if let j = args.firstIndex(of: "--day"), j + 1 < args.count, let d = YMD(iso: args[j + 1]) { day = d }
        let dark = args.contains("--dark")

        let view = PopoverView(snapshot: true, snapshotDay: day)
            .background(dark ? Color(white: 0.13) : Color(red: 0.97, green: 0.97, blue: 0.96))
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: out)
            print("wrote \(out.path)")
        } else {
            print("snapshot failed")
        }
        exit(0)
    }
}
