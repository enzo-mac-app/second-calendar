// swift-tools-version: 6.0
import PackageDescription

// Every target is declared here up front so parallel sessions never have to edit this file.
let package = Package(
    name: "SecondCalendar",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CalendarCore", targets: ["CalendarCore"]),
        .executable(name: "SecondCalendarApp", targets: ["SecondCalendarApp"]),
    ],
    dependencies: [
        // MIT. Chinese lunar dates, solar terms and traditional festivals.
        .package(url: "https://github.com/6tail/lunar-swift", from: "1.1.9"),
        // MIT. Auto-update.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.1"),
    ],
    targets: [
        // No UI: dates, holidays (China / US / Japan), lunar labels, colleague clocks, meeting links.
        .target(name: "CalendarCore", dependencies: [.product(name: "LunarSwift", package: "lunar-swift")]),
        // The menu bar app.
        .executableTarget(
            name: "SecondCalendarApp",
            dependencies: ["CalendarCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
