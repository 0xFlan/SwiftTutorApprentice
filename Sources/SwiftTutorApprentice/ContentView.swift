// ContentView.swift
// ------------------------------------------------------------
// The main window layout. It owns the shared state (the code the
// learner typed, their prediction, and the latest run result) and
// arranges the four areas of the app:
//
//   ┌───────────┬────────────┬───────────┐
//   │ Lesson    │ Code Editor│ Live Coach │
//   ├───────────┴────────────┴───────────┤
//   │ Prediction + Run Output             │
//   └─────────────────────────────────────┘
//
// State lives here and flows DOWN into the panels. Actions (like
// "Run") flow back UP via closures. This one-way data flow is the
// normal SwiftUI pattern.
// ------------------------------------------------------------

import SwiftUI

struct ContentView: View {
    // The current lesson (hardcoded for the MVP).
    private let lesson = Lesson.lesson1

    // The rule-based coach and the local runner. These are plain
    // helpers with no state of their own.
    private let coach = LiveCoach()
    private let runner = SwiftRunner()

    // --- Shared state ---
    // We start empty on purpose so the learner types the code by hand.
    @State private var code: String = ""
    @State private var prediction: String = ""
    @State private var runResult: RunResult?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            // Three resizable columns.
            HSplitView {
                LessonPanel(lesson: lesson)
                    .frame(minWidth: 320, idealWidth: 380)

                CodeEditorPanel(code: $code, onInsertStarter: insertStarter)
                    .frame(minWidth: 320, idealWidth: 420)

                LiveCoachPanel(feedback: coach.feedback(for: code))
                    .frame(minWidth: 280, idealWidth: 320)
            }
            .frame(minHeight: 380)

            Divider()

            // Bottom: prediction + run output.
            RunOutputView(
                prediction: $prediction,
                runResult: runResult,
                isRunning: isRunning,
                onRun: run
            )
            .frame(minHeight: 220)
        }
        .frame(minWidth: 1040, minHeight: 720)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "swift")
                .foregroundStyle(.orange)
                .font(.title2)
            Text("SwiftTutor Apprentice")
                .font(.title3.bold())
            Spacer()
            Text("Lesson \(lesson.id): \(lesson.title)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    /// Fill the editor with the starter line.
    private func insertStarter() {
        code = lesson.codeToType
    }

    /// Run the code locally, off the main thread, then update the UI.
    private func run() {
        isRunning = true
        let codeToRun = code
        Task {
            let result = await runner.run(code: codeToRun)
            // Back on the main thread to update UI state.
            await MainActor.run {
                self.runResult = result
                self.isRunning = false
            }
        }
    }
}
