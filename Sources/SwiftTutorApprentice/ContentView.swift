// ContentView.swift
// ------------------------------------------------------------
// The top-level layout. A NavigationSplitView gives us a native
// Mac sidebar (the lesson list) next to the main work area.
//
//   ┌──────────┬───────────────────────────────────────────┐
//   │ Lessons  │  Lesson │ Code Editor │ Live Coach          │
//   │ sidebar  │  ────────────────────────────────────────  │
//   │          │  Prediction + Run Output                    │
//   └──────────┴───────────────────────────────────────────┘
//
// The AppModel owns all the shared state; this view wires the
// pieces together and hosts the in-app lesson editor sheet.
// ------------------------------------------------------------

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()
    @State private var showingLessonEditor = false
    @State private var showingSettings = false
    @State private var showingWelcome = false

    var body: some View {
        NavigationSplitView {
            LessonListSidebar(
                model: model,
                store: model.store,
                progress: model.progress,
                onManageLessons: { showingLessonEditor = true },
                onOpenSettings: { showingSettings = true }
            )
        } detail: {
            LessonWorkspace(model: model, settings: model.settings, progress: model.progress)
                .navigationTitle("SwiftTutor Apprentice")
                .navigationSubtitle("Lesson \(model.currentDisplayNumber): \(model.currentLesson.title)")
        }
        .frame(minWidth: 1120, minHeight: 740)
        // First-run welcome / onboarding. Driven by ContentView-owned @State
        // (not a binding into model.settings, which ContentView doesn't observe)
        // so dismissing it reliably re-renders and closes the sheet.
        .onAppear {
            showingWelcome = !model.settings.hasSeenWelcome
        }
        .sheet(isPresented: $showingWelcome) {
            WelcomeView(onStart: {
                model.settings.hasSeenWelcome = true
                showingWelcome = false
            })
            .interactiveDismissDisabled()
        }
        // The in-app lesson editor: create/edit/reorder/delete lessons.
        .sheet(isPresented: $showingLessonEditor) {
            LessonEditorView(store: model.store, initialSelection: model.selectedLessonID)
        }
        // In-app settings (including the optional AI coach).
        .sheet(isPresented: $showingSettings) {
            SettingsView(settings: model.settings)
        }
        // If lessons changed while editing, keep the selection valid.
        .onChange(of: model.store.lessons) {
            model.ensureSelectionValid()
        }
    }
}
