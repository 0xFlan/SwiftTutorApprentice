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
import Combine

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

    // MARK: - Walkthrough (narrated "watch it type itself" playback)

    @Published var isPlayingWalkthrough = false
    /// The line currently being narrated (shown as an on-screen caption).
    @Published var walkthroughCaption = ""
    /// The Syntax Lens token currently being explained (for highlighting).
    @Published var activeTokenID: Int?

    private let speaker = NarrationSpeaker()
    private var walkthroughTask: Task<Void, Never>?

    // Keeps the forwarding subscriptions alive.
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Start on the first lesson.
        selectedLessonID = store.lessons.first?.id ?? 1

        // Forward changes from the nested stores so any view observing this
        // AppModel also redraws when the store, progress, or settings change.
        // Without this, a view that observes only `model` (like ContentView)
        // won't react to nested-object changes — the bug behind the welcome
        // sheet not dismissing.
        for publisher in [store.objectWillChange, progress.objectWillChange, settings.objectWillChange] {
            publisher
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &cancellables)
        }
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

    /// Position of the current lesson in the list, and neighbours.
    private var currentIndex: Int {
        store.lessons.firstIndex { $0.id == selectedLessonID } ?? 0
    }
    var hasPreviousLesson: Bool { currentIndex > 0 }
    var hasNextLesson: Bool { currentIndex < store.lessons.count - 1 }

    /// Whether the current lesson has been completed.
    var currentLessonIsComplete: Bool { progress.isComplete(selectedLessonID) }

    /// The 1-based position of a lesson in the list (for display labels).
    /// Uses position, not id, so reordering shows sensible numbers.
    func displayNumber(for lesson: Lesson) -> Int {
        (store.lessons.firstIndex { $0.id == lesson.id } ?? 0) + 1
    }

    /// The current lesson's 1-based position.
    var currentDisplayNumber: Int { displayNumber(for: currentLesson) }

    /// Live coaching feedback for the current code + lesson. For read-only
    /// concept lessons there's no code to check, so we show the explanation.
    var coachFeedback: String {
        if currentLesson.kind == .concept {
            return currentLesson.successMessage.isEmpty ? currentLesson.hint : currentLesson.successMessage
        }
        return coach.feedback(for: code, lesson: currentLesson)
    }

    /// Whether the current lesson is a read-only concept lesson (no run).
    var currentLessonIsConcept: Bool { currentLesson.kind == .concept }

    // MARK: - Actions

    /// Switch lessons and give the learner a clean slate.
    func selectLesson(_ id: Int) {
        guard id != selectedLessonID else { return }
        if isPlayingWalkthrough { stopWalkthrough() }
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

    /// Move to the next lesson in the list (if any).
    func goToNextLesson() {
        guard hasNextLesson else { return }
        selectLesson(store.lessons[currentIndex + 1].id)
    }

    /// Move to the previous lesson in the list (if any).
    func goToPreviousLesson() {
        guard hasPreviousLesson else { return }
        selectLesson(store.lessons[currentIndex - 1].id)
    }

    /// Mark the current lesson complete (used by read-only concept lessons).
    func markCurrentLessonRead() {
        progress.markComplete(selectedLessonID)
    }

    // MARK: - Walkthrough

    /// Play a narrated walkthrough of the current lesson: the code types
    /// itself in, each Syntax Lens token is highlighted and explained aloud,
    /// and (for code lessons) the program is run and its output explained.
    func startWalkthrough() {
        guard !isPlayingWalkthrough else { return }
        isPlayingWalkthrough = true
        activeTokenID = nil
        let lesson = currentLesson
        let number = currentDisplayNumber
        walkthroughTask = Task {
            await self.runWalkthrough(lesson, number: number)
            self.endWalkthrough()
        }
    }

    /// Stop a walkthrough in progress.
    func stopWalkthrough() {
        guard isPlayingWalkthrough else { return }
        walkthroughTask?.cancel()
        speaker.stop()
        endWalkthrough()
    }

    private func endWalkthrough() {
        walkthroughTask = nil
        isPlayingWalkthrough = false
        walkthroughCaption = ""
        activeTokenID = nil
    }

    private func runWalkthrough(_ lesson: Lesson, number: Int) async {
        // Narrate one line: show it as a caption, then speak it.
        func step(_ text: String) async {
            guard !Task.isCancelled else { return }
            walkthroughCaption = text
            await speaker.speak(text)
        }

        code = ""
        runResult = nil

        await step("Lesson \(number): \(lesson.title). \(lesson.goal)")
        guard !Task.isCancelled else { return }

        await step("Here's the code for this lesson. Watch as it's typed in.")
        walkthroughCaption = "Typing the code…"
        await typeCode(lesson.starterCode)
        guard !Task.isCancelled else { return }

        let tokens = lesson.syntaxTokens.isEmpty
            ? SyntaxTokenizer.tokenize(lesson.starterCode)
            : lesson.syntaxTokens
        if !tokens.isEmpty {
            await step("Now let's break it down, piece by piece.")
            for token in tokens {
                guard !Task.isCancelled else { return }
                activeTokenID = token.id
                await step(token.explanation)
            }
            activeTokenID = nil
        }

        if !lesson.syntaxWhy.isEmpty {
            await step(lesson.syntaxWhy)
        }
        guard !Task.isCancelled else { return }

        if lesson.kind == .concept {
            if !lesson.successMessage.isEmpty {
                await step(lesson.successMessage)
            }
        } else if !lesson.expectedOutput.isEmpty {
            await step("Before running it, try to predict what this will print.")
            guard !Task.isCancelled else { return }
            walkthroughCaption = "Running the code…"
            isRunning = true
            let result = await runner.run(code: code)
            isRunning = false
            runResult = result
            guard !Task.isCancelled else { return }
            if result.succeeded {
                let out = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                await step("It ran successfully. The output was: \(out). The program finished with exit code zero, which means success.")
            } else {
                await step("The program didn't run cleanly. Read the standard error output to see what needs fixing.")
            }
        }
        guard !Task.isCancelled else { return }

        await step("That's the lesson. Now try typing it yourself and pressing Run.")
    }

    /// Animate the code appearing character by character, like a screencast.
    private func typeCode(_ target: String) async {
        code = ""
        for character in target {
            guard !Task.isCancelled else { return }
            code.append(character)
            try? await Task.sleep(nanoseconds: 22_000_000) // ~22ms per character
        }
    }

    /// Ask the optional AI coach about the current code. No-op if AI is off.
    func askAI() {
        guard settings.aiEnabled, !isAskingAI else { return }
        isAskingAI = true
        aiResponse = nil
        aiError = nil
        let codeToSend = code
        let lesson = currentLesson
        let provider = settings.aiProvider
        let command = settings.aiCommand
        let apiKey = settings.apiKey
        let apiModel = settings.apiModel

        Task {
            let result: AIResult
            if provider == "api" {
                result = await aiCoach.explainViaAPI(code: codeToSend, lesson: lesson, apiKey: apiKey, model: apiModel)
            } else {
                result = await aiCoach.explain(code: codeToSend, lesson: lesson, command: command)
            }
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
