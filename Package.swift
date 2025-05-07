// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "joseph.mattiello.resume",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6"),
        // .package(url: "https://github.com/Jomy10/SwiftCurses.git", branch: "master"), // Removed SwiftCurses
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .systemLibrary(
            name: "Cncurses",
            pkgConfig: "ncurses",
            providers: [
                .brew(["ncurses"]),
                .apt(["libncurses-dev"])
            ]
        ),
        .executableTarget(
            name: "joseph.mattiello.resume",
            dependencies: [
                .product(name: "Yams", package: "Yams"),
                "Cncurses" // Depend on the system ncurses library
                // .product(name: "SwiftCurses", package: "SwiftCurses"), // Removed SwiftCurses
            ],
            resources: [
                .process("../../Resources/resume.yaml"),
            ]
        ),
        .testTarget(
            name: "joseph.mattiello.resumeTests",
            dependencies: ["joseph.mattiello.resume"]),
    ]
)
