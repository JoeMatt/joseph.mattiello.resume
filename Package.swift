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
        // Changed from .systemLibrary to .target to have more control over flags
        .target(
            name: "Cncurses",
            path: "Sources/Cncurses", // Location of shim.h, shim.c, module.modulemap
            publicHeadersPath: ".",   // shim.h and module.modulemap are directly in Sources/Cncurses
            cSettings: [
                // Use unsafeFlags for absolute header search paths
                .unsafeFlags([
                    "-I/opt/homebrew/opt/ncurses/include",
                    "-I/opt/homebrew/opt/ncurses/include/ncursesw" // Be explicit for ncursesw subfolder
                ]),
                .define("NCURSES_WIDECHAR", to: "1"),
                .define("_DARWIN_C_SOURCE", to: "1")
            ],
            linkerSettings: [
                .linkedLibrary("ncursesw"),
                .unsafeFlags([
                    "-L/opt/homebrew/opt/ncurses/lib"
                ])
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
