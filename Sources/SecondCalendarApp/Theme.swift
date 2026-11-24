import SwiftUI
import AppKit
import CalendarCore

/// Enzomac family colours (same values as TidyGrid's Theme.swift), plus holiday colours.
enum Theme {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }

    static let ink = dynamic(0x121212, 0xF4F3F1)
    static let inkSoft = dynamic(0x6B6964, 0x9C9A96)
    static let hairline = dynamic(0xE2DFDA, 0x3A3A3F)
    static let chip = dynamic(0xEEECE9, 0x2B2B30)
    /// The one accent; always carries ink-black text.
    static let accent = Color(red: 1.0, green: 0.824, blue: 0.2)
    static let onAccent = Color(red: 0.07, green: 0.07, blue: 0.07)

    static let holiday = dynamic(0xD8463F, 0xFF7A70)
    static let workday = dynamic(0x6B6964, 0x8E8C88)
    static let working = dynamic(0x2F9E5B, 0x4CC27E)

    static func region(_ r: Region) -> Color {
        switch r {
        case .cn: return dynamic(0xE5484D, 0xFF6369)
        case .us: return dynamic(0x3E63DD, 0x7B9BFF)
        case .jp: return dynamic(0xC2298A, 0xF06AB5)
        }
    }
}

extension View {
    func sectionLabel() -> some View {
        font(.system(size: 10.5, weight: .bold, design: .rounded))
            .tracking(0.5)
            .foregroundStyle(Theme.inkSoft)
            .textCase(.uppercase)
    }
}

/// A small rounded tag.
struct Tag: View {
    let text: String
    var color: Color = Theme.inkSoft
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(filled ? Color.white : color)
            .background(Capsule().fill(filled ? color : color.opacity(0.14)))
    }
}

/// A plain icon button (SwiftUI-drawn, so it also shows up in rendered snapshots).
struct IconButton: View {
    let systemName: String
    var help: String = ""
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Theme.chip : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

/// The yellow call-to-action pill (Join, Save).
struct AccentButton: View {
    let title: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .foregroundStyle(Theme.onAccent)
                .background(Capsule().fill(Theme.accent))
                .opacity(disabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
