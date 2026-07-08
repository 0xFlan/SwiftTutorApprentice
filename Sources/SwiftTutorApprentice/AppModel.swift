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

    /// The editable curriculum (loaded from JSON, seeded from defaults).
    let store = LessonStore()

    /// Persistent record of which lessons are complete.
    let progress = ProgressStore()

    /// App preferences (including the optional AI coach toggle).
    let settings = AppSettings()

    // Plain helpers with no state of their own.
    private let coach = LiveCoach()
    private let runner = SwiftRunner()
    private let aiCoach = AICoach()

    // MARK: - Published state (views redraw when these change)

    @Published var selectedLessonID: Int
    @Published var code: String = ""
    @Published var prediction: String = ""
    @Published var runResult: RunResult?
    @Published var isRunning = false

    /// Optional AI coach output (nil until the learner asks).
    @Published var aiResponse: String?
    @Published var aiError: String?
    @Published var isAskingAI = false

    init() {
        // Start on the first lesson.
        selectedLessonID = store.lessons.first?.id ?? 1
    }

    // MARK: - Derived values

    /// All lessons, in order.
    var lessons: [Lesson] { store.lessons }

    /// The lesson currently being shown (falls back safely if the
    /// selected lesson was deleted or renumbered).
    var currentLesson: Lesson {
        store.lesson(id: selectedLessonID)
            ?? store.lessons.first
            ?? Curriculum.defaultLessons[0]
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
        aiResponse = nil
        aiError = nil
    }

    /// After the lesson list changes (edits/deletes/reorder), make sure the
    /// selected lesson still exists; if not, fall back to the first lesson.
    func ensureSelectionValid() {
        if store.lesson(id: selectedLessonID) == nil {
            selectedLessonID = store.lessons.first?.id ?? selectedLessonID
            code = ""
            prediction = ""
            runResult = nil
        }
    }

    /// Fill the editor with the current lesson's starter code.
    func insertStarter() {
        code = currentLesson.starterCode
    }

    /// Ask the optional AI coach about the current code. No-op if AI is off.
    func askAI() {
        guard settings.aiEnabled, !isAskingAI else { return }
        isAskingAI = true
        aiResponse = nil
        aiError = nil
        let codeToSend = code
        let lesson = currentLesson
        let command = settings.aiCommand

        Task {
            let result = await aiCoach.explain(code: codeToSend, lesson: lesson, command: command)
            self.isAskingAI = false
            if let error = result.errorMessage {
                self.aiError = error
            } else {
                self.aiResponse = result.text
            }
        }
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
