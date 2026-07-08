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

    var body: some View {
        NavigationSplitView {
            LessonListSidebar(
                model: model,
                store: model.store,
                progress: model.progress,
                onManageLessons: { showingLessonEditor = true }
            )
        } detail: {
            LessonWorkspace(model: model)
                .navigationTitle("SwiftTutor Apprentice")
                .navigationSubtitle("Lesson \(model.currentLesson.id): \(model.currentLesson.title)")
        }
        .frame(minWidth: 1120, minHeight: 740)
        // The in-app lesson editor: create/edit/reorder/delete lessons.
        .sheet(isPresented: $showingLessonEditor) {
            LessonEditorView(store: model.store, initialSelection: model.selectedLessonID)
        }
        // If lessons changed while editing, keep the selection valid.
        .onChange(of: model.store.lessons) {
            model.ensureSelectionValid()
        }
    }
}
