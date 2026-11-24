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
    ],
    targets: [
        // No UI: dates, holidays (China / US / Japan), lunar labels, colleague clocks, meeting links.
        .target(name: "CalendarCore", dependencies: [.product(name: "LunarSwift", package: "lunar-swift")]),
        // The menu bar app.
        .executableTarget(name: "SecondCalendarApp", dependencies: ["CalendarCore"]),
        .testTarget(name: "CalendarCoreTests", dependencies: ["CalendarCore"]),
    ],
    swiftLanguageModes: [.v5]
)
