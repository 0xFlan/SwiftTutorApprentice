// swift-tools-version:5.9
//
// Package.swift
// ------------------------------------------------------------
// This file tells Swift Package Manager (SwiftPM) how to build
// the app. It is the "recipe" for the project.
//
// We use tools-version 5.9 (Swift 5 language mode) on purpose:
// it keeps the code simple for a beginner and avoids Swift 6's
// strict concurrency checking, which is not needed for this MVP.
//
// Build and run from Terminal with:
//     swift build
//     swift run SwiftTutorApprentice
// ------------------------------------------------------------

import PackageDescription

let package = Package(
    name: "SwiftTutorApprentice",
    // We target macOS 14 so we can use modern SwiftUI APIs.
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // An "executable" target produces an app you can run,
        // rather than a library other code links against.
        .executableTarget(
            name: "SwiftTutorApprentice",
            path: "Sources/SwiftTutorApprentice"
        ),
        .testTarget(
            name: "SwiftTutorApprenticeTests",
            dependencies: ["SwiftTutorApprentice"],
            path: "Tests/SwiftTutorApprenticeTests",
            resources: [.copy("Fixtures")]
        )
    ]
)
