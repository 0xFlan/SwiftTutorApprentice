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
// The AppModel owns all the shared state; this view just wires
// the pieces together.
// ------------------------------------------------------------

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        NavigationSplitView {
            LessonListSidebar(model: model, progress: model.progress)
        } detail: {
            LessonWorkspace(model: model)
                .navigationTitle("SwiftTutor Apprentice")
                .navigationSubtitle("Lesson \(model.currentLesson.id): \(model.currentLesson.title)")
        }
        .frame(minWidth: 1120, minHeight: 740)
    }
}
