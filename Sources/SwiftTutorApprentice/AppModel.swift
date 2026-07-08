// AppModel.swift
// ------------------------------------------------------------
// The "brain" of the app. It holds the state shared across the
// whole window (which lesson is selected, the code being typed,
// the prediction, the latest run result) and the actions that
// change that state (selecting a lesson, running code).
//
// This is a view model: an ObservableObject that SwiftUI views
// watch. When an @Published value changes, the views redraw.
// Keeping state here — instead of scattered across views — is a
// standard, scalable SwiftUI pattern.
//
// @MainActor means all of this runs on the main thread, which is
// where UI state must be updated.
// ------------------------------------------------------------

import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {

    /// The full curriculum (all lessons, in order).
    let lessons = Curriculum.lessons

    /// Persistent record of which lessons are complete.
    let progress = ProgressStore()

    // Plain helpers with no state of their own.
    private let coach = LiveCoach()
    private let runner = SwiftRunner()

    // MARK: - Published state (views redraw when these change)

    @Published var selectedLessonID: Int
    @Published var code: String = ""
    @Published var prediction: String = ""
    @Published var runResult: RunResult?
    @Published var isRunning = false

    init() {
        // Start on the first lesson.
        selectedLessonID = Curriculum.lessons.first?.id ?? 1
    }

    // MARK: - Derived values

    /// The lesson currently being shown.
    var currentLesson: Lesson {
        Curriculum.lesson(id: selectedLessonID) ?? lessons[0]
    }

    /// Live coaching feedback for the current code + lesson.
    var coachFeedback: String {
        coach.feedback(for: code, lesson: currentLesson)
    }

    // MARK: - Actions

    /// Switch lessons and give the learner a clean slate.
    func selectLesson(_ id: Int) {
        guard id != selectedLessonID else { return }
        selectedLessonID = id
        code = ""
        prediction = ""
        runResult = nil
    }

    /// Fill the editor with the current lesson's starter code.
    func insertStarter() {
        code = currentLesson.starterCode
    }

    /// Run the code locally, then update the UI and progress.
    func run() {
        isRunning = true
        let codeToRun = code
        let lesson = currentLesson

        Task {
            let result = await runner.run(code: codeToRun)
            // Back on the main actor here, so it's safe to touch state.
            self.runResult = result
            self.isRunning = false

            // Auto-mark the lesson complete when the program ran cleanly
            // AND produced exactly the output the lesson is aiming for.
            if result.succeeded, !lesson.expectedOutput.isEmpty {
                let actual = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let expected = lesson.expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if actual == expected {
                    self.progress.markComplete(lesson.id)
                }
            }
        }
    }
}
