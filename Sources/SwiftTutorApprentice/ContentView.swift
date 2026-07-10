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
    @State private var canPresentLearningStages = false

    var body: some View {
        NavigationSplitView {
            LessonListSidebar(
                model: model,
                store: model.store,
                progress: model.progress,
                onManageLessons: {
                    canPresentLearningStages = false
                    showingLessonEditor = true
                },
                onOpenSettings: {
                    canPresentLearningStages = false
                    showingSettings = true
                }
            )
        } detail: {
            LessonWorkspace(
                model: model,
                settings: model.settings,
                progress: model.progress,
                canPresentLearningStages: canPresentLearningStages
            )
                .navigationTitle("SwiftTutor Apprentice")
                .navigationSubtitle("Lesson \(model.currentDisplayNumber): \(model.currentLesson.title)")
        }
        .frame(minWidth: 680, minHeight: 520)
        // Parent sheets own the learning-stage lifecycle gate. Stage sheets
        // resume only after the active parent sheet has actually dismissed.
        .onAppear {
            let needsWelcome = !model.settings.hasSeenWelcome
            canPresentLearningStages = !needsWelcome
            showingWelcome = needsWelcome
        }
        .sheet(isPresented: $showingWelcome, onDismiss: {
            canPresentLearningStages = true
        }) {
            WelcomeView(onStart: {
                model.settings.hasSeenWelcome = true
                showingWelcome = false
            })
            .interactiveDismissDisabled()
        }
        // The in-app lesson editor: create/edit/reorder/delete lessons.
        .sheet(isPresented: $showingLessonEditor, onDismiss: {
            canPresentLearningStages = true
        }) {
            LessonEditorView(store: model.store, initialSelection: model.selectedLessonID)
        }
        // In-app settings (including the optional AI coach).
        .sheet(isPresented: $showingSettings, onDismiss: {
            canPresentLearningStages = true
        }) {
            SettingsView(settings: model.settings)
        }
        // If lessons changed while editing, keep the selection valid.
        .onChange(of: model.store.lessons) {
            model.ensureSelectionValid()
        }
    }
}
