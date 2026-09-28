// swift-tools-version:6.0

// Pure calendar/formatting logic shared by the watch app and the widget
// extension. No SwiftUI or WidgetKit here, so everything can be unit-tested
// on the Mac with `swift test` — no watch simulator needed.

import PackageDescription

let package = Package(
    name: "HebcalWatchCore",
    platforms: [
        .watchOS(.v10),
        .macOS(.v13),
    ],
    products: [
        .library(name: "HebcalWatchCore", targets: ["HebcalWatchCore"]),
    ],
    dependencies: [
        // Same URL and branch as the Xcode project's package reference, so
        // SwiftPM resolves both to a single copy.
        .package(url: "https://github.com/hebcal/hebcal-swift.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "HebcalWatchCore",
            dependencies: [.product(name: "Hebcal", package: "hebcal-swift")]),
        .testTarget(
            name: "HebcalWatchCoreTests",
            dependencies: ["HebcalWatchCore"],
            exclude: ["Snapshots"]),
    ]
)
