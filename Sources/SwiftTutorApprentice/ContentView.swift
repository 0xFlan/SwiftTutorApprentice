// ContentView.swift
// ------------------------------------------------------------
// The top-level route. Course Home and the course workspace have
// separate identities so navigation never reuses stale split-view
// or scroll state between them.
//
//   Course Home  ──open──▶  Course Workspace
//       ▲                         │
//       └──────── Home ───────────┘
//
// The AppModel owns all the shared state; this view wires the
// root together and owns the one-time welcome sheet.
// ------------------------------------------------------------

import SwiftUI

struct ContentView: View {
    @StateObject private var model: AppModel
    @State private var showingWelcome = false
    @State private var canPresentLearningStages = false

    init() {
        _model = StateObject(wrappedValue: AppModel())
    }

    init(model: AppModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        Group {
            switch model.route {
            case .courseHome:
                CourseHomeView(model: model)
            case .course:
                CourseWorkspaceView(
                    model: model,
                    canPresentLearningStages: canPresentLearningStages
                )
            }
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
    }
}
