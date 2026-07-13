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

enum AppRoute: Hashable {
    case courseHome
    case course(CourseID)
}

enum LessonSelectionOrigin: Hashable {
    case courseEntry
    case programmatic
    case direct
}

struct LessonSelectionTransaction: Identifiable, Hashable {
    let key: LessonKey
    let origin: LessonSelectionOrigin
    let generation: UInt64

    var id: UInt64 { generation }
}

struct AICoachRequest {
    let code: String
    let lesson: Lesson
    let provider: String
    let command: String
    let apiKey: String
    let model: String
}

@MainActor
final class AppModel: ObservableObject {

    /// The editable curriculum (loaded from JSON, seeded from defaults).
    let store: LessonStore

    /// Persistent record of which lessons are complete.
    let progress: ProgressStore

    /// App preferences (including the optional AI coach toggle).
    let settings: AppSettings

    private let contentRegistry: CourseContentRegistry

    // Plain helpers with no state of their own.
    private let coach = LiveCoach()
    private let runCode: (String) async -> RunResult
    private let requestAI: (AICoachRequest) async -> AIResult

    // MARK: - Published state (views redraw when these change)

    @Published private(set) var route: AppRoute = .courseHome
    @Published private(set) var selectedLessonKey: LessonKey?
    @Published private(set) var lessonSelectionTransaction: LessonSelectionTransaction?
    @Published private(set) var courseOpenError: String?
    private var selectionGeneration: UInt64 = 0
    var selectedLessonID: Int {
        guard let selectedLessonKey,
              selectedLessonKey.courseID == .swiftDevelopment,
              let legacyID = Int(selectedLessonKey.localID.rawValue)
        else { return store.lessons.first?.id ?? 1 }
        return legacyID
    }
    @Published var code: String = ""
    @Published var prediction: String = ""
    @Published var runResult: RunResult?
    @Published var isRunning = false

    /// Optional AI coach output (nil until the learner asks).
    @Published var aiResponse: String?
    @Published var aiError: String?
    @Published var isAskingAI = false

    private var runTask: Task<Void, Never>?
    private var aiTask: Task<Void, Never>?
    private var runGeneration: UInt64 = 0
    private var aiGeneration: UInt64 = 0
    private var workspaceCancellation: (id: UUID, cancel: () -> Void)?

    // Keeps the forwarding subscriptions alive.
    private var cancellables = Set<AnyCancellable>()

    convenience init() {
        let store = LessonStore()
        let progress = ProgressStore()
        let settings = AppSettings()
        self.init(
            store: store,
            progress: progress,
            settings: settings,
            contentRegistry: CourseContentRegistry(
                providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: store)]
            )
        )
    }

    init(
        store: LessonStore,
        progress: ProgressStore,
        settings: AppSettings,
        contentRegistry: CourseContentRegistry,
        runCode: ((String) async -> RunResult)? = nil,
        requestAI: ((AICoachRequest) async -> AIResult)? = nil
    ) {
        self.store = store
        self.progress = progress
        self.settings = settings
        self.contentRegistry = contentRegistry
        let runner = SwiftRunner()
        let aiCoach = AICoach()
        self.runCode = runCode ?? { code in
            await runner.run(code: code)
        }
        self.requestAI = requestAI ?? { request in
            if request.provider == "api" {
                return await aiCoach.explainViaAPI(
                    code: request.code,
                    lesson: request.lesson,
                    apiKey: request.apiKey,
                    model: request.model
                )
            }
            return await aiCoach.explain(
                code: request.code,
                lesson: request.lesson,
                command: request.command
            )
        }
        selectedLessonKey = nil

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

    /// Course Home's display projection comes from the same injected registry,
    /// progress store, and destination policy used by `openCourse`. Missing or
    /// invalid available content therefore fails closed instead of constructing
    /// an unrelated provider from the editable lesson store.
    func courseHomeCards() -> [CourseHomeCardModel] {
        CourseCatalog.default.definitions.map { definition in
            let progressDocument = progress.progress(for: definition.id)
            var displayDefinition = definition
            var displayProvider: (any CourseContentProvider)?
            var destination: CourseDestination?

            do {
                let provider = try contentRegistry.provider(for: definition.id)
                if let resolved = courseDestination(
                    for: definition.id,
                    provider: provider
                ), provider.contains(resolved.lessonKey) {
                    displayProvider = provider
                    destination = resolved
                } else {
                    displayDefinition = definition.withAvailability(.contentUnavailable)
                }
            } catch CourseContentError.comingNext {
                // The catalog remains the source of truth for Coming next.
            } catch {
                displayDefinition = definition.withAvailability(.contentUnavailable)
            }

            return CourseHomeCardModel(
                course: displayDefinition,
                provider: displayProvider,
                progress: progressDocument,
                destination: destination
            )
        }
    }

    // MARK: - Actions

    /// Switch lessons and give the learner a clean slate.
    func selectLesson(_ key: LessonKey, origin: LessonSelectionOrigin) {
        guard key != selectedLessonKey else { return }
        cancelTransientLessonWork()
        selectionGeneration &+= 1
        selectedLessonKey = key
        lessonSelectionTransaction = LessonSelectionTransaction(
            key: key,
            origin: origin,
            generation: selectionGeneration
        )
        code = ""
        prediction = ""
        runResult = nil
        aiResponse = nil
        aiError = nil
    }

    func selectLesson(_ id: Int) {
        selectLesson(.swift(id), origin: .direct)
    }

    func openCourse(_ courseID: CourseID) {
        courseOpenError = nil
        guard let definition = CourseCatalog.default[courseID] else {
            courseOpenError = "This course is unavailable."
            return
        }

        let provider: any CourseContentProvider
        do {
            provider = try contentRegistry.provider(for: courseID)
        } catch CourseContentError.comingNext {
            courseOpenError = "\(definition.title) is coming next."
            return
        } catch {
            courseOpenError = "\(definition.title) content is unavailable."
            return
        }

        guard let destination = courseDestination(for: courseID, provider: provider),
              provider.contains(destination.lessonKey)
        else {
            courseOpenError = "\(definition.title) content is unavailable."
            return
        }

        cancelTransientLessonWork()
        if destination.lessonKey != selectedLessonKey {
            selectionGeneration &+= 1
            selectedLessonKey = destination.lessonKey
            lessonSelectionTransaction = LessonSelectionTransaction(
                key: destination.lessonKey,
                origin: selectionOrigin(for: destination.label),
                generation: selectionGeneration
            )
        }
        route = .course(courseID)
    }

    private func selectionOrigin(
        for destinationLabel: CourseActionLabel
    ) -> LessonSelectionOrigin {
        switch destinationLabel {
        case .start:
            return .courseEntry
        case .continue, .review:
            return .programmatic
        }
    }

    private func courseDestination(
        for courseID: CourseID,
        provider: any CourseContentProvider
    ) -> CourseDestination? {
        let orderedKeys = provider.modules.flatMap { module in
            module.orderedLessonLocalIDs.map {
                LessonKey(courseID: courseID, localID: $0)
            }
        }
        let completed = Set(progress.progress(for: courseID).completedLessonLocalIDs.map {
            LessonKey(courseID: courseID, localID: $0)
        })
        return CourseDestinationResolver.resolve(
            orderedLessons: orderedKeys,
            completed: completed,
            lastLesson: progress.lastLessonKey(in: courseID),
            hasMeaningfulActivity: progress.hasMeaningfulActivity(in: courseID)
        )
    }

    func goHome() {
        cancelTransientLessonWork()
        selectionGeneration &+= 1
        route = .courseHome
        selectedLessonKey = nil
        lessonSelectionTransaction = nil
        courseOpenError = nil
    }

    @discardableResult
    func registerWorkspaceCancellation(_ cancellation: @escaping () -> Void) -> UUID {
        let previous = workspaceCancellation
        workspaceCancellation = nil
        let id = UUID()
        workspaceCancellation = (id, cancellation)
        previous?.cancel()
        return id
    }

    func unregisterWorkspaceCancellation(_ id: UUID) {
        guard workspaceCancellation?.id == id else { return }
        workspaceCancellation = nil
    }

    private func cancelTransientLessonWork() {
        let workspaceCancellation = workspaceCancellation
        self.workspaceCancellation = nil
        workspaceCancellation?.cancel()
        runGeneration &+= 1
        aiGeneration &+= 1
        runTask?.cancel()
        runTask = nil
        aiTask?.cancel()
        aiTask = nil
        code = ""
        prediction = ""
        runResult = nil
        isRunning = false
        aiResponse = nil
        aiError = nil
        isAskingAI = false
    }

    /// After the lesson list changes (edits/deletes/reorder), make sure the
    /// selected lesson still exists; if not, fall back to the first lesson.
    func ensureSelectionValid() {
        guard let selectedLessonKey,
              selectedLessonKey.courseID == .swiftDevelopment,
              let selectedLessonID = Int(selectedLessonKey.localID.rawValue),
              store.lesson(id: selectedLessonID) == nil,
              let fallback = store.lessons.first
        else { return }
        selectLesson(.swift(fallback.id), origin: .programmatic)
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

    /// Ask the optional AI coach about the current code. No-op if AI is off.
    func askAI() {
        guard settings.aiEnabled,
              let key = selectedLessonKey
        else { return }
        aiGeneration &+= 1
        aiTask?.cancel()
        let operationGeneration = aiGeneration
        let selectionAtStart = selectionGeneration
        isAskingAI = true
        aiResponse = nil
        aiError = nil
        let codeToSend = code
        let lesson = currentLesson
        let provider = settings.aiProvider
        let command = settings.aiCommand
        let apiKey = settings.apiKey
        let apiModel = settings.apiModel

        let request = AICoachRequest(
            code: codeToSend,
            lesson: lesson,
            provider: provider,
            command: command,
            apiKey: apiKey,
            model: apiModel
        )
        aiTask = Task {
            let result = await requestAI(request)
            guard self.aiGeneration == operationGeneration,
                  self.selectionGeneration == selectionAtStart,
                  self.selectedLessonKey == key
            else { return }
            self.aiTask = nil
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
        guard let key = selectedLessonKey else { return }
        runGeneration &+= 1
        runTask?.cancel()
        let operationGeneration = runGeneration
        let selectionAtStart = selectionGeneration
        isRunning = true
        let codeToRun = code
        let lesson = currentLesson

        runTask = Task {
            let result = await runCode(codeToRun)
            guard self.runGeneration == operationGeneration,
                  self.selectionGeneration == selectionAtStart,
                  self.selectedLessonKey == key
            else { return }
            // Back on the main actor here, so it's safe to touch state.
            self.runTask = nil
            self.runResult = result
            self.isRunning = false

            if result.workspaceWasSaved {
                self.progress.recordSavedWorkspaceActivity(for: key)
            }

            // Auto-mark the lesson complete when the program ran cleanly
            // AND produced exactly the output the lesson is aiming for.
            if result.succeeded, !lesson.expectedOutput.isEmpty {
                let actual = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                let expected = lesson.expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if actual == expected {
                    self.progress.markComplete(key)
                }
            }
        }
    }
}

private extension CourseDefinition {
    func withAvailability(_ availability: CourseAvailability) -> CourseDefinition {
        CourseDefinition(
            id: id,
            title: title,
            summary: summary,
            symbolName: symbolName,
            accentName: accentName,
            availability: availability,
            releaseLevel: releaseLevel,
            runtimeKind: runtimeKind,
            certificationTargets: certificationTargets,
            activeObjectiveSetID: activeObjectiveSetID
        )
    }
}
