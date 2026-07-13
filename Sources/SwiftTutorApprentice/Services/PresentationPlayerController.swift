import Combine
import Foundation

enum PresentationVisualPhase: Equatable {
    case before
    case after
}

@MainActor
final class PresentationPlayerController: ObservableObject {
    @Published private(set) var entryMode: PresentationEntryMode
    @Published private(set) var currentSceneIndex: Int?
    @Published private(set) var isPlaying = false
    @Published private(set) var showsTranscript = false
    @Published private(set) var narrationEnabled = true
    @Published private(set) var visualPhase: PresentationVisualPhase = .before

    private(set) var lessonKey: LessonKey
    private(set) var presentation: LessonPresentation
    private var savedState: LessonPresentationState?

    private let now: () -> Date
    private let persist: (LessonKey, LessonPresentationState) -> Void
    private let waitForAdvance: () async -> Void
    private let narrator: PresentationNarrating
    private let reduceMotion: () -> Bool
    private var narrationRequested = true
    private var playbackTask: Task<Void, Never>?

    init(
        lessonKey: LessonKey,
        presentation: LessonPresentation,
        savedState: LessonPresentationState?,
        now: @escaping () -> Date = Date.init,
        persist: @escaping (LessonKey, LessonPresentationState) -> Void,
        waitForAdvance: @escaping () async -> Void,
        narrator: PresentationNarrating? = nil,
        reduceMotion: @escaping () -> Bool = { false }
    ) {
        self.lessonKey = lessonKey
        self.presentation = presentation
        self.savedState = savedState
        self.now = now
        self.persist = persist
        self.waitForAdvance = waitForAdvance
        self.narrator = narrator ?? NarrationSpeaker()
        self.reduceMotion = reduceMotion
        let entryMode = PresentationPlayerStateMachine.entryMode(
            presentation: presentation,
            savedState: savedState
        )
        self.entryMode = entryMode
        self.currentSceneIndex = Self.initialSceneIndex(
            for: entryMode,
            in: presentation
        )
        self.narrationEnabled = narrationRequested
            && self.narrator.isAvailable(for: presentation.narrationLocale)
    }

    func start() {
        guard let state = PresentationPlayerStateMachine.start(
            presentation: presentation,
            savedState: savedState,
            now: now()
        ) else { return }
        apply(state)
    }

    func play() {
        guard isPlaying == false,
              let scene = currentScene else { return }

        isPlaying = true
        visualPhase = .before
        let capturedKey = lessonKey
        let capturedPresentationID = presentation.id
        let narrationLocale = presentation.narrationLocale
        let shouldNarrate = narrationEnabled
            && narrator.isAvailable(for: narrationLocale)
        let shouldReduceMotion = reduceMotion()
        if shouldReduceMotion {
            visualPhase = .after
        }
        playbackTask = Task { [weak self, narrator, waitForAdvance] in
            guard self?.playbackIsCurrent(
                lessonKey: capturedKey,
                presentationID: capturedPresentationID
            ) == true else { return }
            if shouldReduceMotion == false {
                self?.visualPhase = .after
            }
            if shouldNarrate {
                await narrator.speak(scene.narration, locale: narrationLocale)
            }
            guard self?.playbackIsCurrent(
                lessonKey: capturedKey,
                presentationID: capturedPresentationID
            ) == true else { return }

            await waitForAdvance()

            guard self?.playbackIsCurrent(
                lessonKey: capturedKey,
                presentationID: capturedPresentationID
            ) == true else { return }
            self?.advanceAfterPlayback()
        }
    }

    func pause() {
        cancelPlayback()
    }

    func next() {
        if currentSceneIndex == presentation.scenes.indices.last {
            complete()
            return
        }
        transition(resumePlayback: isPlaying) {
            PresentationPlayerStateMachine.next(
                presentation: presentation,
                savedState: savedState,
                now: now()
            )
        }
    }

    func back() {
        transition(resumePlayback: isPlaying) {
            PresentationPlayerStateMachine.back(
                presentation: presentation,
                savedState: savedState,
                now: now()
            )
        }
    }

    func replay() {
        transition(resumePlayback: isPlaying) {
            PresentationPlayerStateMachine.replay(
                presentation: presentation,
                savedState: savedState,
                now: now()
            )
        }
    }

    func skip() {
        cancelPlayback()
        let state = PresentationPlayerStateMachine.skip(
            presentation: presentation,
            savedState: savedState,
            now: now()
        )
        apply(state)
    }

    func toggleTranscript() {
        showsTranscript.toggle()
    }

    func toggleNarration() {
        guard narrator.isAvailable(for: presentation.narrationLocale) else {
            narrationEnabled = false
            return
        }
        narrationRequested.toggle()
        narrationEnabled = narrationRequested
        if narrationEnabled == false {
            narrator.stop()
        }
    }

    func deactivate() {
        cancelPlayback()
    }

    func replacePresentation(
        for lessonKey: LessonKey,
        presentation: LessonPresentation,
        savedState: LessonPresentationState?
    ) {
        deactivate()
        self.lessonKey = lessonKey
        self.presentation = presentation
        self.savedState = savedState
        let entryMode = PresentationPlayerStateMachine.entryMode(
            presentation: presentation,
            savedState: savedState
        )
        self.entryMode = entryMode
        currentSceneIndex = Self.initialSceneIndex(
            for: entryMode,
            in: presentation
        )
        visualPhase = .before
        showsTranscript = false
        narrationEnabled = narrationRequested
            && narrator.isAvailable(for: presentation.narrationLocale)
    }

    var currentScene: PresentationScene? {
        guard let currentSceneIndex,
              presentation.scenes.indices.contains(currentSceneIndex) else {
            return nil
        }
        return presentation.scenes[currentSceneIndex]
    }

    var currentCaption: String? {
        currentScene?.caption
    }

    var currentStaticDescription: String? {
        currentScene?.staticDescription
    }

    private func apply(_ state: LessonPresentationState) {
        savedState = state
        currentSceneIndex = Self.sceneIndex(for: state.lastSceneID, in: presentation)
        visualPhase = .before
        switch state.status {
        case .notStarted:
            entryMode = .expandedPoster
        case .started:
            if let sceneID = state.lastSceneID {
                entryMode = .compactResume(sceneID: sceneID)
            } else {
                entryMode = .expandedPoster
            }
        case .skipped:
            currentSceneIndex = nil
            entryMode = .compactSummary(status: .skipped)
        case .completed:
            entryMode = .compactSummary(status: .completed)
        }
        persist(lessonKey, state)
    }

    private func complete() {
        cancelPlayback()
        guard let state = PresentationPlayerStateMachine.complete(
            presentation: presentation,
            savedState: savedState,
            now: now()
        ) else { return }
        apply(state)
    }

    private func transition(
        resumePlayback: Bool,
        state: () -> LessonPresentationState?
    ) {
        cancelPlayback()
        guard let nextState = state() else { return }
        apply(nextState)
        if resumePlayback {
            play()
        }
    }

    private func cancelPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        narrator.stop()
        isPlaying = false
    }

    private func playbackIsCurrent(
        lessonKey: LessonKey,
        presentationID: String
    ) -> Bool {
        Task.isCancelled == false
            && self.lessonKey == lessonKey
            && presentation.id == presentationID
            && isPlaying
    }

    private func advanceAfterPlayback() {
        playbackTask = nil
        next()
    }

    private static func sceneIndex(
        for sceneID: String?,
        in presentation: LessonPresentation
    ) -> Int? {
        guard let sceneID else { return nil }
        return presentation.scenes.firstIndex { $0.id == sceneID }
    }

    private static func initialSceneIndex(
        for entryMode: PresentationEntryMode,
        in presentation: LessonPresentation
    ) -> Int? {
        guard case .compactResume(let sceneID) = entryMode else { return nil }
        return sceneIndex(for: sceneID, in: presentation)
    }
}
