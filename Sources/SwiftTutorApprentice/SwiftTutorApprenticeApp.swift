// SwiftTutorApprenticeApp.swift
// ------------------------------------------------------------
// This is the ENTRY POINT of the app. The `@main` attribute
// tells Swift "start the program here."
//
// A SwiftUI `App` describes the windows (Scenes) the app shows.
// We show one window containing `ContentView`.
//
// Why the AppDelegate?
// When a SwiftUI app is launched from Swift Package Manager
// (`swift run ...`) instead of from a normal .app bundle, macOS
// treats it as a background process by default: the window may
// not come to the front and it may not appear in the Dock.
// Setting the activation policy to `.regular` and activating the
// app fixes that so the window behaves like a normal Mac app.
// ------------------------------------------------------------

import SwiftUI
import AppKit

@main
struct SwiftTutorApprenticeApp: App {
    // Connects our AppDelegate (below) into the SwiftUI lifecycle.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // A comfortable default size for the three-column layout.
        .defaultSize(width: 1280, height: 860)
    }
}

/// Handles a few app-level details that SwiftUI alone doesn't cover
/// well for a SwiftPM-launched app.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Make this a normal foreground app (Dock icon + focus).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Quit the app when its last window closes (normal Mac behavior).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
