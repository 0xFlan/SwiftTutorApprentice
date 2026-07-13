import AVFoundation
import XCTest
@testable import SwiftTutorApprentice

final class PresentationPlayerControllerTests: XCTestCase {
    @MainActor
    func testNarrationStopDetachesOldUtteranceBeforeImmediateSpeak() async {
        var utterances: [AVSpeechUtterance] = []
        var stopCount = 0
        let speaker = NarrationSpeaker(
            startSpeaking: { utterances.append($0) },
            stopSpeaking: { stopCount += 1 },
            voiceResolver: { _ in NarrationVoiceSelection(voice: nil) }
        )
        var firstFinished = false
        var secondFinished = false

        Task {
            await speaker.speak("first")
            firstFinished = true
        }
        await waitUntil { utterances.count == 1 }
        let firstUtterance = utterances[0]

        speaker.stop()
        await waitUntil { firstFinished }
        XCTAssertEqual(stopCount, 1)

        Task {
            await speaker.speak("second")
            secondFinished = true
        }
        await waitUntil { utterances.count == 2 }
        let secondUtterance = utterances[1]

        speaker.speechSynthesizer(
            AVSpeechSynthesizer(),
            didCancel: firstUtterance
        )
        await Task.yield()
        XCTAssertFalse(
            secondFinished,
            "The late callback for the stopped utterance must not finish the new speech."
        )

        speaker.speechSynthesizer(
            AVSpeechSynthesizer(),
            didFinish: secondUtterance
        )
        await waitUntil { secondFinished }
    }

    @MainActor
    func testNarrationSpeakerResolvesAndSpeaksTheExactAuthoredLocale() async {
        var utterances: [AVSpeechUtterance] = []
        var resolvedLocales: [String] = []
        let speaker = NarrationSpeaker(
            startSpeaking: { utterances.append($0) },
            stopSpeaking: {},
            voiceResolver: { locale in
                resolvedLocales.append(locale)
                return locale == "en-US"
                    ? NarrationVoiceSelection(voice: nil)
                    : nil
            }
        )

        XCTAssertTrue(speaker.isAvailable(for: "en-US"))
        XCTAssertFalse(speaker.isAvailable(for: "fr-CA"))

        Task { await speaker.speak("Authored narration", locale: "en-US") }
        await waitUntil { utterances.count == 1 }

        XCTAssertEqual(resolvedLocales, ["en-US", "fr-CA", "en-US"])
        speaker.speechSynthesizer(AVSpeechSynthesizer(), didFinish: utterances[0])
    }

    @MainActor
    func testCancelledNarrationSpeakerEntryDoesNotResolveOrStartSpeech() async {
        var entered = false
        var resolvedLocales: [String] = []
        var utterances: [AVSpeechUtterance] = []
        let speaker = NarrationSpeaker(
            startSpeaking: { utterances.append($0) },
            stopSpeaking: {},
            voiceResolver: { locale in
                resolvedLocales.append(locale)
                return NarrationVoiceSelection(voice: nil)
            }
        )

        let task = Task {
            entered = true
            withUnsafeCurrentTask { $0?.cancel() }
            await speaker.speak("Must not start", locale: "en-US")
        }
        await waitUntil { entered }
        await Task.yield()

        XCTAssertTrue(task.isCancelled)
        XCTAssertTrue(resolvedLocales.isEmpty)
        XCTAssertTrue(utterances.isEmpty)
        speaker.stop()
    }

    @MainActor
    func testImmediatePauseCancelsBeforeQueuedNarrationBegins() async {
        await assertImmediatePlaybackCancellation { controller, _ in
            controller.pause()
        }
    }

    @MainActor
    func testImmediateDeactivateCancelsBeforeQueuedNarrationBegins() async {
        await assertImmediatePlaybackCancellation { controller, _ in
            controller.deactivate()
        }
    }

    @MainActor
    func testImmediateReplacementCancelsBeforeOldNarrationBegins() async {
        await assertImmediatePlaybackCancellation { controller, presentation in
            controller.replacePresentation(
                for: .swift(2),
                presentation: Self.makePresentation(
                    id: "replacement",
                    locale: "fr-CA"
                ),
                savedState: nil
            )
            XCTAssertNotEqual(controller.presentation.id, presentation.id)
        }
    }

    @MainActor
    func testControllerUsesAuthoredLocaleAndRecalculatesAvailabilityOnReplacement() async {
        let narrator = NarrationSpy(availableLocales: ["en-US"])
        let unavailable = Self.makePresentation(locale: "fr-CA")
        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: unavailable,
            savedState: nil,
            persist: { _, _ in },
            waitForAdvance: {},
            narrator: narrator
        )

        XCTAssertFalse(controller.narrationEnabled)
        controller.start()
        controller.play()
        await Task.yield()
        XCTAssertTrue(narrator.spoken.isEmpty)
        XCTAssertEqual(controller.currentCaption, "Caption for scene 1.")
        XCTAssertEqual(unavailable.transcript, "Swift stores Hello in greeting.")

        let available = Self.makePresentation(id: "presentation-2", locale: "en-US")
        controller.replacePresentation(
            for: .swift(2),
            presentation: available,
            savedState: nil
        )
        XCTAssertTrue(controller.narrationEnabled)
        controller.start()
        controller.play()
        await waitUntil { narrator.spoken.count == 1 }
        XCTAssertEqual(narrator.spoken[0].text, "Narration for scene 1.")
        XCTAssertEqual(narrator.spoken[0].locale, "en-US")

        controller.replacePresentation(
            for: .swift(3),
            presentation: unavailable,
            savedState: nil
        )
        XCTAssertFalse(controller.narrationEnabled)
    }

    @MainActor
    func testLearnerNarrationOffPersistsAcrossAvailableReplacementsWithoutSpeaking() async {
        let narrator = NarrationSpy(availableLocales: ["en-US"])
        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: Self.makePresentation(),
            savedState: nil,
            persist: { _, _ in },
            waitForAdvance: {},
            narrator: narrator
        )
        XCTAssertTrue(controller.narrationEnabled)

        controller.toggleNarration()
        XCTAssertFalse(controller.narrationEnabled)
        controller.replacePresentation(
            for: .swift(2),
            presentation: Self.makePresentation(id: "available-replacement"),
            savedState: nil
        )
        XCTAssertFalse(controller.narrationEnabled)

        controller.start()
        controller.play()
        for _ in 0..<3 { await Task.yield() }
        XCTAssertTrue(narrator.spoken.isEmpty)
    }

    @MainActor
    func testLearnerNarrationOffSurvivesUnavailableThenAvailableReplacement() async {
        let narrator = NarrationSpy(availableLocales: ["en-US"])
        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: Self.makePresentation(),
            savedState: nil,
            persist: { _, _ in },
            waitForAdvance: {},
            narrator: narrator
        )
        controller.toggleNarration()

        controller.replacePresentation(
            for: .swift(2),
            presentation: Self.makePresentation(
                id: "unavailable-replacement",
                locale: "fr-CA"
            ),
            savedState: nil
        )
        XCTAssertFalse(controller.narrationEnabled)
        controller.replacePresentation(
            for: .swift(3),
            presentation: Self.makePresentation(id: "available-again"),
            savedState: nil
        )
        XCTAssertFalse(controller.narrationEnabled)

        controller.start()
        controller.play()
        for _ in 0..<3 { await Task.yield() }
        XCTAssertTrue(narrator.spoken.isEmpty)
    }

    @MainActor
    func testConstructionDoesNotPersistAndStartDoes() {
        let key = LessonKey.swift(1)
        let presentation = Self.makePresentation()
        let now = Date(timeIntervalSinceReferenceDate: 123)
        var writes: [(LessonKey, LessonPresentationState)] = []

        let controller = PresentationPlayerController(
            lessonKey: key,
            presentation: presentation,
            savedState: nil,
            now: { now },
            persist: { writes.append(($0, $1)) },
            waitForAdvance: {}
        )

        XCTAssertEqual(controller.entryMode, .expandedPoster)
        XCTAssertNil(controller.currentSceneIndex)
        XCTAssertEqual(writes.count, 0)

        controller.start()

        XCTAssertEqual(controller.currentSceneIndex, 0)
        XCTAssertEqual(controller.visualPhase, .before)
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.first?.0, key)
        XCTAssertEqual(
            writes.first?.1,
            LessonPresentationState(
                status: .started,
                lastSceneID: "scene-1",
                presentationRevision: 3,
                firstStartedAt: now,
                lastOpenedAt: now,
                replayCount: 0,
                presentationID: presentation.id
            )
        )
    }

    @MainActor
    func testConstructionUsesTaskTenResolvedResumeSceneWithoutPersisting() {
        let presentation = Self.makePresentation(sceneCount: 2)
        let staleState = LessonPresentationState(
            status: .started,
            lastSceneID: "removed-scene",
            presentationRevision: 2,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 0
        )
        var writeCount = 0

        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: presentation,
            savedState: staleState,
            persist: { _, _ in writeCount += 1 },
            waitForAdvance: {}
        )

        XCTAssertEqual(controller.entryMode, .compactResume(sceneID: "scene-1"))
        XCTAssertEqual(controller.currentSceneIndex, 0)
        XCTAssertEqual(controller.currentScene?.id, "scene-1")
        XCTAssertEqual(writeCount, 0)
    }

    @MainActor
    func testPlaybackCancellationBoundary() async {
        let originalKey = LessonKey.swift(1)
        let replacementKey = LessonKey.swift(2)
        let original = Self.makePresentation(sceneCount: 2)
        let replacement = Self.makePresentation(id: "presentation-2", sceneCount: 2)
        let narrator = NarrationSpy()
        let gate = AdvanceGate()
        var writes: [(LessonKey, LessonPresentationState)] = []

        let controller = PresentationPlayerController(
            lessonKey: originalKey,
            presentation: original,
            savedState: nil,
            now: { Date(timeIntervalSinceReferenceDate: 123) },
            persist: { writes.append(($0, $1)) },
            waitForAdvance: { await gate.wait() },
            narrator: narrator
        )
        controller.start()
        writes.removeAll()

        controller.play()
        await waitUntil { await gate.waitCount == 1 }
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(narrator.spoken.map(\.text), ["Narration for scene 1."])

        controller.pause()
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(narrator.stopCount, 1)
        await gate.resumeNext()
        await Task.yield()
        XCTAssertEqual(controller.currentSceneIndex, 0)
        XCTAssertTrue(writes.isEmpty)

        controller.play()
        await waitUntil { await gate.waitCount == 2 }
        controller.next()
        await waitUntil { await gate.waitCount == 3 }
        XCTAssertEqual(controller.currentSceneIndex, 1)
        XCTAssertEqual(writes.count, 1)
        XCTAssertEqual(writes.last?.1.lastSceneID, "scene-2")
        XCTAssertEqual(narrator.spoken.last?.text, "Narration for scene 2.")
        await gate.resumeNext()
        await Task.yield()
        XCTAssertEqual(controller.currentSceneIndex, 1)
        XCTAssertEqual(writes.count, 1)

        controller.back()
        await waitUntil { await gate.waitCount == 4 }
        XCTAssertEqual(controller.currentSceneIndex, 0)
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes.last?.1.lastSceneID, "scene-1")

        controller.replay()
        await waitUntil { await gate.waitCount == 5 }
        XCTAssertEqual(controller.currentSceneIndex, 0)
        XCTAssertEqual(writes.count, 3)
        XCTAssertEqual(writes.last?.1.replayCount, 1)

        controller.deactivate()
        XCTAssertFalse(controller.isPlaying)
        let countBeforeReplacement = writes.count
        controller.replacePresentation(
            for: replacementKey,
            presentation: replacement,
            savedState: nil
        )
        await gate.resumeAll()
        await Task.yield()
        XCTAssertEqual(writes.count, countBeforeReplacement)
        XCTAssertNil(controller.currentSceneIndex)

        controller.start()
        XCTAssertEqual(writes.count, countBeforeReplacement + 1)
        XCTAssertEqual(writes.last?.0, replacementKey)
        XCTAssertEqual(writes.last?.1.lastSceneID, "scene-1")
    }

    @MainActor
    func testCompletionSkipAndAccessibilityPreferences() async {
        let key = LessonKey.swift(1)
        let presentation = Self.makePresentation()
        let narrator = NarrationSpy()
        narrator.availableLocales = []
        var writes: [(LessonKey, LessonPresentationState)] = []

        let controller = PresentationPlayerController(
            lessonKey: key,
            presentation: presentation,
            savedState: nil,
            now: { Date(timeIntervalSinceReferenceDate: 456) },
            persist: { writes.append(($0, $1)) },
            waitForAdvance: {},
            narrator: narrator,
            reduceMotion: { true }
        )

        XCTAssertFalse(controller.narrationEnabled)
        controller.toggleNarration()
        XCTAssertFalse(controller.narrationEnabled)

        controller.start()
        XCTAssertEqual(controller.currentCaption, "Caption for scene 1.")
        XCTAssertEqual(
            controller.currentStaticDescription,
            "Static description for scene 1."
        )
        let writeCountBeforeTranscript = writes.count
        controller.toggleTranscript()
        XCTAssertTrue(controller.showsTranscript)
        XCTAssertEqual(writes.count, writeCountBeforeTranscript)

        controller.play()
        XCTAssertEqual(controller.visualPhase, .after)
        controller.pause()

        controller.next()
        XCTAssertEqual(writes.last?.0, key)
        XCTAssertEqual(writes.last?.1.status, .completed)
        XCTAssertEqual(controller.entryMode, .compactSummary(status: .completed))

        controller.replay()
        controller.skip()
        XCTAssertEqual(writes.last?.1.status, .skipped)
        XCTAssertEqual(controller.entryMode, .compactSummary(status: .skipped))
        XCTAssertNil(controller.currentSceneIndex)
    }

    @MainActor
    func testPlaybackAutomaticallyContinuesUntilFinalCompletion() async {
        let gate = AdvanceGate()
        var writes: [LessonPresentationState] = []
        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: Self.makePresentation(sceneCount: 2),
            savedState: nil,
            persist: { _, state in writes.append(state) },
            waitForAdvance: { await gate.wait() },
            narrator: NarrationSpy()
        )
        controller.start()
        writes.removeAll()

        controller.play()
        await waitUntil { await gate.waitCount == 1 }
        await gate.resumeNext()
        await waitUntil { await gate.waitCount == 2 }

        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(controller.currentSceneIndex, 1)
        XCTAssertEqual(writes.map(\.lastSceneID), ["scene-2"])

        await gate.resumeNext()
        await waitUntil { writes.last?.status == .completed }
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(writes.last?.status, .completed)
    }

    @MainActor
    func testSuspendedPlaybackDoesNotRetainControllerOrPerformLateWork() async {
        let gate = AdvanceGate()
        let narrator = NarrationSpy()
        var writes: [LessonPresentationState] = []
        weak var weakController: PresentationPlayerController?
        var controller: PresentationPlayerController? = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: Self.makePresentation(sceneCount: 2),
            savedState: nil,
            persist: { _, state in writes.append(state) },
            waitForAdvance: { await gate.wait() },
            narrator: narrator
        )
        weakController = controller
        controller?.start()
        writes.removeAll()
        controller?.play()
        await waitUntil { await gate.waitCount == 1 }
        XCTAssertEqual(narrator.spoken.map(\.text), ["Narration for scene 1."])

        controller = nil
        await Task.yield()
        XCTAssertNil(
            weakController,
            "A suspended playback task must not keep its controller alive after navigation releases it."
        )

        await gate.resumeAll()
        await Task.yield()
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(narrator.spoken.map(\.text), ["Narration for scene 1."])
    }

    private static func makePresentation(
        id: String = "presentation-1",
        sceneCount: Int = 1,
        locale: String = "en-US"
    ) -> LessonPresentation {
        let state = PresentationVisualState(
            code: "let greeting = \"Hello\"",
            codeTokens: [PresentationCodeToken(id: "token-let", text: "let")],
            values: [PresentationValue(id: "value-greeting", name: "greeting", value: "Hello")],
            output: nil,
            outputTargetID: nil,
            description: "A constant named greeting stores Hello."
        )
        let scenes = (1...sceneCount).map { index in
            PresentationScene(
                id: "scene-\(index)",
                title: "Scene \(index)",
                caption: "Caption for scene \(index).",
                narration: "Narration for scene \(index).",
                staticDescription: "Static description for scene \(index).",
                visualKind: .valueBinding,
                focusTargets: [PresentationFocusTarget(kind: .codeToken, id: "token-let")],
                before: state,
                after: state
            )
        }
        return LessonPresentation(
            id: id,
            title: "Constants",
            posterDescription: "See how a constant binds a value.",
            posterState: state,
            scenes: scenes,
            transcript: "Swift stores Hello in greeting.",
            narrationLocale: locale,
            finalRecallQuestionID: "recall-1",
            aiCodeExercise: nil,
            conceptIDs: [],
            objectiveMappings: [],
            provenance: LessonPresentationProvenance(source: .bundled, revision: 3)
        )
    }

    @MainActor
    private func assertImmediatePlaybackCancellation(
        action: (PresentationPlayerController, LessonPresentation) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let presentation = Self.makePresentation(sceneCount: 2)
        let narrator = NarrationSpy(availableLocales: ["en-US"])
        let gate = AdvanceGate()
        var writes: [LessonPresentationState] = []
        let controller = PresentationPlayerController(
            lessonKey: .swift(1),
            presentation: presentation,
            savedState: nil,
            persist: { _, state in writes.append(state) },
            waitForAdvance: { await gate.wait() },
            narrator: narrator
        )
        controller.start()
        writes.removeAll()

        controller.play()
        action(controller, presentation)
        for _ in 0..<5 { await Task.yield() }
        let waitCount = await gate.waitCount

        XCTAssertFalse(controller.isPlaying, file: file, line: line)
        XCTAssertEqual(controller.visualPhase, .before, file: file, line: line)
        XCTAssertTrue(narrator.spoken.isEmpty, file: file, line: line)
        XCTAssertEqual(waitCount, 0, file: file, line: line)
        XCTAssertTrue(writes.isEmpty, file: file, line: line)
    }

    @MainActor
    private func waitUntil(
        _ condition: @escaping () async -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }
}

@MainActor
private final class NarrationSpy: PresentationNarrating {
    struct Spoken: Equatable {
        let text: String
        let locale: String
    }

    var availableLocales: Set<String>
    var spoken: [Spoken] = []
    var stopCount = 0

    init(availableLocales: Set<String> = ["en-US"]) {
        self.availableLocales = availableLocales
    }

    func isAvailable(for locale: String) -> Bool {
        availableLocales.contains(locale)
    }

    func speak(_ text: String, locale: String) async {
        spoken.append(Spoken(text: text, locale: locale))
    }

    func stop() {
        stopCount += 1
    }
}

private actor AdvanceGate {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var waitCount = 0

    func wait() async {
        waitCount += 1
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeNext() {
        guard continuations.isEmpty == false else { return }
        continuations.removeFirst().resume()
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}
