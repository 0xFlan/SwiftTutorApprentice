import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class LessonLearningLoopTests: XCTestCase {
    func testConsumedRecallFocusDoesNotReplayWhenChildRemounts() throws {
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        let question = try XCTUnwrap(lesson.deepContent?.recallQuestions.first)
        let lessonKey = LessonKey.swift(lesson.id)
        let session = LessonWorkspaceSession(waitForAdvance: {})
        session.activate(
            for: lessonKey,
            presentation: lesson.presentation,
            savedState: nil,
            persist: { _, _ in }
        )
        session.requestRecallFocus(for: lessonKey)
        let applications = RecallFocusApplicationCounter()
        let host = NSHostingView(
            rootView: RecallFocusRemountHarness(
                session: session,
                lessonKey: lessonKey,
                question: question,
                mountGeneration: 0,
                applications: applications
            )
            .frame(width: 520, height: 320)
        )
        host.frame = NSRect(x: 0, y: 0, width: 520, height: 320)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        settleRecallHarness(host)
        XCTAssertEqual(applications.count, 1)
        XCTAssertNotNil(
            session.recallFocusRequest,
            "Focus acknowledgement must retain the request until outer scrolling also acknowledges it."
        )
        XCTAssertEqual(session.activeRecallFocusGeneration(for: lessonKey), 0)

        host.rootView = RecallFocusRemountHarness(
            session: session,
            lessonKey: lessonKey,
            question: question,
            mountGeneration: 1,
            applications: applications
        )
        .frame(width: 520, height: 320)
        settleRecallHarness(host)
        XCTAssertEqual(
            applications.count,
            1,
            "Reconstructing Recall must not reapply an acknowledged focus request."
        )

        session.requestRecallFocus(for: lessonKey)
        settleRecallHarness(host)
        XCTAssertEqual(applications.count, 2, "A new Recall request must apply exactly once.")
    }

    private func settleRecallHarness(_ view: NSView) {
        for _ in 0..<5 {
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
    }

    func testRecallRequestClearsOnlyAfterFocusAndScrollAcknowledgeInEitherOrder() {
        let session = LessonWorkspaceSession(waitForAdvance: {})
        let key = LessonKey.swift(1)

        session.requestRecallFocus(for: key)
        let focusFirstGeneration = session.recallFocusGeneration
        session.acknowledgeRecallFocus(generation: focusFirstGeneration, lessonKey: key)
        XCTAssertNotNil(session.recallFocusRequest)
        XCTAssertEqual(session.activeRecallFocusGeneration(for: key), 0)
        XCTAssertEqual(session.recallFocusGeneration, focusFirstGeneration)
        session.acknowledgeRecallScroll(generation: focusFirstGeneration, lessonKey: key)
        XCTAssertNil(session.recallFocusRequest)

        session.requestRecallFocus(for: key)
        let scrollFirstGeneration = session.recallFocusGeneration
        session.acknowledgeRecallScroll(generation: scrollFirstGeneration, lessonKey: key)
        XCTAssertNotNil(session.recallFocusRequest)
        XCTAssertEqual(session.activeRecallFocusGeneration(for: key), scrollFirstGeneration)
        XCTAssertEqual(session.recallFocusGeneration, scrollFirstGeneration)
        session.acknowledgeRecallFocus(generation: scrollFirstGeneration, lessonKey: key)
        XCTAssertNil(session.recallFocusRequest)
    }

    func testRecallRequestIgnoresStaleAcknowledgementsAndRetainsUnmountedRequests() {
        let session = LessonWorkspaceSession(waitForAdvance: {})
        let lessonA = LessonKey.swift(1)
        let lessonB = LessonKey.swift(2)

        session.requestRecallFocus(for: lessonA)
        let staleGeneration = session.recallFocusGeneration
        session.requestRecallFocus(for: lessonB)
        let currentGeneration = session.recallFocusGeneration
        XCTAssertEqual(currentGeneration, staleGeneration + 1)
        XCTAssertEqual(session.recallFocusRequest?.lessonKey, lessonB)

        session.acknowledgeRecallFocus(generation: staleGeneration, lessonKey: lessonA)
        session.acknowledgeRecallScroll(generation: staleGeneration, lessonKey: lessonA)
        XCTAssertEqual(session.recallFocusRequest?.lessonKey, lessonB)
        XCTAssertEqual(session.recallFocusRequest?.generation, currentGeneration)
        XCTAssertEqual(
            session.activeRecallFocusGeneration(for: lessonB),
            currentGeneration,
            "An unmounted Recall card must retain its pending focus request."
        )

        session.acknowledgeRecallScroll(generation: currentGeneration, lessonKey: lessonB)
        session.acknowledgeRecallFocus(generation: currentGeneration, lessonKey: lessonB)
        XCTAssertNil(session.recallFocusRequest)
        session.requestRecallFocus(for: lessonB)
        XCTAssertEqual(session.recallFocusGeneration, currentGeneration + 1)
        XCTAssertEqual(session.activeRecallFocusGeneration(for: lessonB), currentGeneration + 1)
    }

    func testRecallFocusRequestTargetsEnabledSemanticControlBeforeAcknowledging() throws {
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        let question = try XCTUnwrap(lesson.deepContent?.recallQuestions.first)
        let scenarios: [(String, Bool?, Bool, String)] = [
            ("unanswered", nil, true, "lesson-recall-focus-target-choice-0"),
            ("persisted-correct", true, true, "lesson-recall-focus-target-continue"),
            ("persisted-incorrect", false, true, "lesson-recall-focus-target-continue"),
            ("answered-without-continue", false, false, "lesson-recall-focus-target-feedback")
        ]

        for (name, persisted, showsContinue, expectedMarker) in scenarios {
            let applications = RecallFocusApplicationCounter()
            let host = NSHostingView(
                rootView: RecallFocusTargetHarness(
                    question: question,
                    persistedWasCorrect: persisted,
                    showsContinue: showsContinue,
                    applications: applications
                )
                .frame(width: 520, height: 360)
            )
            host.frame = NSRect(x: 0, y: 0, width: 520, height: 360)
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.orderOut(nil) }
            settleRecallHarness(host)

            XCTAssertEqual(applications.count, 1, name)
            XCTAssertEqual(markers(named: expectedMarker, in: host).count, 1, name)
            for forbidden in [
                "lesson-recall-focus-target-choice-0",
                "lesson-recall-focus-target-continue",
                "lesson-recall-focus-target-feedback"
            ] where forbidden != expectedMarker {
                XCTAssertTrue(markers(named: forbidden, in: host).isEmpty, name)
            }
        }
    }

    private func markers(named identifier: String, in view: NSView) -> [NSView] {
        var matches = view.identifier?.rawValue == identifier ? [view] : []
        for child in view.subviews {
            matches.append(contentsOf: markers(named: identifier, in: child))
        }
        return matches
    }

    func testDelayedWorkspaceExpansionCommandCannotExpandReplacementLesson() {
        let session = LessonWorkspaceSession(waitForAdvance: {})
        var selectedLessonKey = LessonKey.swift(1)
        session.activate(
            for: selectedLessonKey,
            presentation: SwiftPilotPresentationContent.lesson1,
            savedState: nil,
            persist: { _, _ in }
        )
        let lessonACommand = LessonWorkspace.playerExpansionCommand(
            session: session,
            owningLessonKey: selectedLessonKey
        )

        selectedLessonKey = .swift(2)
        session.activate(
            for: selectedLessonKey,
            presentation: SwiftPilotPresentationContent.lesson2,
            savedState: nil,
            persist: { _, _ in }
        )
        lessonACommand()

        XCTAssertNil(
            session.playerExpansionLessonKey,
            "A retained Lesson A callback must not mark replacement Lesson B expanded."
        )

        session.activate(
            for: selectedLessonKey,
            presentation: SwiftPilotPresentationContent.lesson2,
            savedState: nil,
            persist: { _, _ in }
        )
        let lessonBCommand = LessonWorkspace.playerExpansionCommand(
            session: session,
            owningLessonKey: selectedLessonKey
        )
        lessonBCommand()
        XCTAssertEqual(session.playerExpansionLessonKey, selectedLessonKey)
    }

    func testReduceMotionUpdateBeforeActivationIsUsedByPlayback() throws {
        let session = LessonWorkspaceSession(waitForAdvance: {})
        session.updateReduceMotion(true)

        session.activate(
            for: .swift(1),
            presentation: SwiftPilotPresentationContent.lesson1,
            savedState: nil,
            persist: { _, _ in }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.start()
        controller.play()

        XCTAssertEqual(controller.visualPhase, .after)
    }

    func testReduceMotionUpdateAfterActivationIsUsedBySubsequentPlayback() async throws {
        let session = LessonWorkspaceSession(waitForAdvance: {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        })
        session.activate(
            for: .swift(1),
            presentation: SwiftPilotPresentationContent.lesson1,
            savedState: nil,
            persist: { _, _ in }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.start()

        controller.play()
        XCTAssertEqual(
            controller.visualPhase,
            .before,
            "The default must preserve the authored before-to-after path."
        )
        await Task.yield()
        XCTAssertEqual(controller.visualPhase, .after)
        controller.pause()

        session.updateReduceMotion(true)
        controller.play()

        XCTAssertEqual(controller.visualPhase, .after)
        controller.pause()
    }

    func testInitialLessonSurfacePolicy() throws {
        var writes: [LessonPresentationState] = []
        let session = LessonWorkspaceSession(waitForAdvance: {})
        let presentation = SwiftPilotPresentationContent.lesson1
        let legacyFixture = try ProgressFixture()
        legacyFixture.progress.markComplete(.swift(1))
        legacyFixture.progress.markDeepLessonViewed(.swift(1))
        XCTAssertNil(legacyFixture.progress.presentationState(for: .swift(1)))

        session.activate(
            for: .swift(1),
            presentation: presentation,
            savedState: legacyFixture.progress.presentationState(for: .swift(1)),
            persist: { _, state in writes.append(state) }
        )

        let firstController = try XCTUnwrap(session.controller)
        XCTAssertEqual(firstController.entryMode, .expandedPoster)
        XCTAssertFalse(firstController.isPlaying)
        XCTAssertTrue(writes.isEmpty, "Opening the poster must not persist presentation activity.")
        XCTAssertTrue(legacyFixture.progress.isComplete(.swift(1)))
        XCTAssertTrue(legacyFixture.progress.hasViewedDeepLesson(.swift(1)))

        firstController.start()
        firstController.play()
        XCTAssertTrue(firstController.isPlaying)

        let started = LessonPresentationState(
            status: .started,
            lastSceneID: presentation.scenes[1].id,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 0
        )
        session.activate(
            for: .swift(1),
            presentation: presentation,
            savedState: started,
            persist: { _, _ in }
        )
        XCTAssertFalse(firstController.isPlaying, "Replacing a lesson must deactivate its old controller.")
        XCTAssertEqual(session.controller?.entryMode, .compactResume(sceneID: presentation.scenes[1].id))

        for status in [PresentationStatus.skipped, .completed] {
            session.activate(
                for: .swift(1),
                presentation: presentation,
                savedState: LessonPresentationState(
                    status: status,
                    lastSceneID: presentation.scenes.last?.id,
                    presentationRevision: presentation.provenance.revision,
                    firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
                    lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
                    replayCount: 0
                ),
                persist: { _, _ in }
            )
            XCTAssertEqual(session.controller?.entryMode, .compactSummary(status: status))
        }

        // Legacy completion and Deep Lesson evidence are deliberately not inputs
        // to presentation entry. A nil presentation is the only direct-workspace path.
        session.activate(
            for: .swift(1),
            presentation: presentation,
            savedState: nil,
            persist: { _, _ in }
        )
        XCTAssertEqual(session.controller?.entryMode, .expandedPoster)
        session.activate(
            for: .swift(99),
            presentation: nil,
            savedState: nil,
            persist: { _, _ in }
        )
        XCTAssertNil(session.controller)
    }

    func testPlaybackCompletionAndSkipDoNotRequestRecallFocus() throws {
        let fixture = try ProgressFixture()
        let session = LessonWorkspaceSession(waitForAdvance: {})
        let presentation = SwiftPilotPresentationContent.lesson1
        var states: [LessonPresentationState] = []

        session.activate(
            for: .swift(1),
            presentation: presentation,
            savedState: nil,
            persist: { _, state in states.append(state) }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.start()
        let generationBeforeCompletion = session.recallFocusGeneration
        for _ in presentation.scenes {
            controller.next()
        }

        XCTAssertEqual(session.recallFocusGeneration, generationBeforeCompletion)
        XCTAssertNil(session.recallFocusRequest)
        XCTAssertEqual(states.last?.status, .completed)
        XCTAssertTrue(fixture.progress.progress(for: .swiftDevelopment).stageEvents.isEmpty)

        session.activate(
            for: .swift(1),
            presentation: presentation,
            savedState: nil,
            persist: { _, state in states.append(state) }
        )
        let generationBeforeSkip = session.recallFocusGeneration
        try XCTUnwrap(session.controller).skip()

        XCTAssertEqual(session.recallFocusGeneration, generationBeforeSkip)
        XCTAssertNil(session.recallFocusRequest)
        XCTAssertEqual(states.last?.status, .skipped)
        XCTAssertTrue(fixture.progress.progress(for: .swiftDevelopment).stageEvents.isEmpty)

        session.recordRecallAnswer(
            lessonKey: .swift(1),
            questionID: presentation.finalRecallQuestionID,
            wasCorrect: false,
            progress: fixture.progress
        )
        session.recordRecallAnswer(
            lessonKey: .swift(1),
            questionID: presentation.finalRecallQuestionID,
            wasCorrect: true,
            progress: fixture.progress
        )

        let recall = fixture.progress.progress(for: .swiftDevelopment).stageEvents.filter {
            $0.kind == .recallAnswered
        }
        XCTAssertEqual(recall.count, 1)
        XCTAssertEqual(recall.first?.wasCorrect, false, "The first answer wins even when it is incorrect.")

        session.continueAfterRecall(modify: nil)
        XCTAssertEqual(session.practiceFocusGeneration, 1)

        let lesson = Curriculum.defaultLessons[0]
        let content = try XCTUnwrap(lesson.deepContent)
        let modify = LessonStagePresentation(
            lessonKey: .swift(lesson.id),
            lesson: lesson,
            content: content,
            existingEditorCode: lesson.starterCode
        )
        session.continueAfterRecall(modify: modify)
        guard case .modify(let opened)? = session.activeLessonStage else {
            return XCTFail("Recall Continue should open Modify when it exists.")
        }
        XCTAssertEqual(opened.lesson.id, lesson.id)
    }

    func testAICodeReviewRecordsOnlySubmittedAttempts() throws {
        let fixture = try ProgressFixture()
        let submittedAt = Date(timeIntervalSinceReferenceDate: 500)
        var nextID = 0
        let session = LessonWorkspaceSession(
            now: { submittedAt },
            makeAttemptID: {
                nextID += 1
                return AttemptID(rawValue: "attempt-\(nextID)")
            },
            waitForAdvance: {}
        )
        let presentation = SwiftPilotPresentationContent.lesson1
        let exercise = try XCTUnwrap(presentation.aiCodeExercise)

        XCTAssertTrue(fixture.progress.progress(for: .swiftDevelopment).assessmentAttempts.isEmpty)
        XCTAssertEqual(nextID, 0, "Opening and answering without Submit must not allocate an attempt.")

        let failed = AICodeReviewEvaluator.evaluate(
            exercise: exercise,
            answers: exercise.claims.map {
                AICodeClaimAnswer(claimID: $0.id, answer: !$0.isCorrect)
            }
        )
        let first = try XCTUnwrap(session.submitAICodeReview(
            failed,
            lessonKey: .swift(1),
            presentation: presentation,
            exercise: exercise,
            progress: fixture.progress
        ))
        XCTAssertEqual(first.id.rawValue, "attempt-1")
        XCTAssertEqual(first.lessonKey, .swift(1))
        XCTAssertEqual(first.activityID.rawValue, exercise.id)
        XCTAssertEqual(first.itemVariantID.rawValue, "\(exercise.id):default")
        XCTAssertEqual(first.conceptIDs, exercise.conceptIDs)
        XCTAssertEqual(first.objectiveMappings, presentation.objectiveMappings)
        XCTAssertEqual(first.scaffoldLevel, .none)
        XCTAssertEqual(first.result, .failed)
        XCTAssertEqual(first.contentRevision, presentation.provenance.revision)
        XCTAssertFalse(first.wasPreviouslySeen)
        XCTAssertEqual(first.submittedAt, submittedAt)

        let passed = AICodeReviewEvaluator.evaluate(
            exercise: exercise,
            answers: exercise.claims.map {
                AICodeClaimAnswer(claimID: $0.id, answer: $0.isCorrect)
            }
        )
        let second = try XCTUnwrap(session.submitAICodeReview(
            passed,
            lessonKey: .swift(1),
            presentation: presentation,
            exercise: exercise,
            progress: fixture.progress
        ))
        XCTAssertEqual(second.id.rawValue, "attempt-2")
        XCTAssertEqual(second.result, .passed)
        XCTAssertTrue(second.wasPreviouslySeen)
        XCTAssertEqual(
            fixture.progress.progress(for: .swiftDevelopment).assessmentAttempts.map(\.id),
            [first.id, second.id]
        )

        fixture.progress.record(second)
        XCTAssertEqual(
            fixture.progress.progress(for: .swiftDevelopment).assessmentAttempts.count,
            2,
            "Re-recording a retained attempt ID must be idempotent."
        )
    }

    func testFailedAssessmentSaveRetriesTheRetainedIdentityAndTimestamp() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LessonAttemptRetry-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("progress.json")
        var writeCount = 0
        let progress = ProgressStore(
            fileURL: fileURL,
            now: { Date(timeIntervalSinceReferenceDate: 1) },
            writeData: { data, url in
                writeCount += 1
                if writeCount == 1 {
                    throw CocoaError(.fileWriteUnknown)
                }
                try data.write(to: url, options: .atomic)
            }
        )
        let submittedAt = Date(timeIntervalSinceReferenceDate: 900)
        var generatedIDs = 0
        let session = LessonWorkspaceSession(
            now: { submittedAt },
            makeAttemptID: {
                generatedIDs += 1
                return AttemptID(rawValue: "retained-attempt")
            },
            waitForAdvance: {}
        )
        let presentation = SwiftPilotPresentationContent.lesson1
        let exercise = try XCTUnwrap(presentation.aiCodeExercise)
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: exercise,
            answers: exercise.claims.map {
                AICodeClaimAnswer(claimID: $0.id, answer: $0.isCorrect)
            }
        )

        let submitted = try XCTUnwrap(session.submitAICodeReview(
            evaluation,
            lessonKey: .swift(1),
            presentation: presentation,
            exercise: exercise,
            progress: progress
        ))
        XCTAssertEqual(progress.saveError, "The file couldn’t be saved.")
        XCTAssertEqual(session.pendingAssessmentAttempt, submitted)
        XCTAssertEqual(generatedIDs, 1)

        session.retryPendingAssessmentSave(progress: progress)

        XCTAssertNil(progress.saveError)
        XCTAssertNil(session.pendingAssessmentAttempt)
        XCTAssertEqual(generatedIDs, 1, "A persistence retry must not regenerate identity or time.")
        let reopened = ProgressStore(fileURL: fileURL, now: Date.init)
        XCTAssertEqual(
            reopened.progress(for: .swiftDevelopment).assessmentAttempts,
            [submitted]
        )
        XCTAssertEqual(submitted.submittedAt, submittedAt)
    }

    func testPreviouslySeenDerivesFromPriorPersistedItemVariant() throws {
        let fixture = try ProgressFixture()
        let presentation = SwiftPilotPresentationContent.lesson1
        let exercise = try XCTUnwrap(presentation.aiCodeExercise)
        let variant = ItemVariantID(rawValue: "\(exercise.id):default")
        fixture.progress.record(
            AssessmentAttempt(
                id: AttemptID(rawValue: "prior-attempt"),
                lessonKey: .swift(1),
                activityID: ActivityID(rawValue: "prior-activity"),
                itemVariantID: variant,
                conceptIDs: [],
                objectiveMappings: [],
                scaffoldLevel: .none,
                result: .failed,
                contentRevision: 1,
                wasPreviouslySeen: false,
                submittedAt: Date(timeIntervalSinceReferenceDate: 1)
            )
        )
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: exercise,
            answers: exercise.claims.map {
                AICodeClaimAnswer(claimID: $0.id, answer: $0.isCorrect)
            }
        )
        let session = LessonWorkspaceSession(
            makeAttemptID: { AttemptID(rawValue: "current-attempt") },
            waitForAdvance: {}
        )

        let current = try XCTUnwrap(session.submitAICodeReview(
            evaluation,
            lessonKey: .swift(1),
            presentation: presentation,
            exercise: exercise,
            progress: fixture.progress
        ))

        XCTAssertTrue(
            current.wasPreviouslySeen,
            "Previously seen is an item-variant property, not an activity-instance property."
        )
    }

    func testModifyUsesFullLessonKeyAcrossOverlappingCourseLocalIDs() throws {
        let fixture = try ProgressFixture()
        let session = LessonWorkspaceSession(waitForAdvance: {})
        let lesson = Curriculum.defaultLessons[0]
        let networkingKey = LessonKey(
            courseID: .networking,
            localID: LessonLocalID(rawValue: "1")
        )
        let presentation = LessonStagePresentation(
            lessonKey: networkingKey,
            lesson: lesson,
            content: try XCTUnwrap(lesson.deepContent),
            existingEditorCode: lesson.starterCode
        )

        session.recordModifyPassed(presentation, progress: fixture.progress)

        XCTAssertTrue(fixture.progress.hasPassedModify(networkingKey))
        XCTAssertFalse(
            fixture.progress.hasPassedModify(.swift(1)),
            "Overlapping local IDs in another course must not write Swift progress."
        )
        XCTAssertFalse(
            session.canReplaceEditor(
                for: presentation,
                selectedLessonKey: .swift(1)
            ),
            "A matching Int local ID from the wrong course must not replace editor state."
        )
        XCTAssertTrue(
            session.canReplaceEditor(
                for: presentation,
                selectedLessonKey: networkingKey
            )
        )
    }
}

@MainActor
private final class RecallFocusApplicationCounter {
    var count = 0
}

private struct RecallFocusRemountHarness: View {
    @ObservedObject var session: LessonWorkspaceSession
    let lessonKey: LessonKey
    let question: RecallQuestion
    let mountGeneration: Int
    let applications: RecallFocusApplicationCounter

    private var activeGeneration: UInt64 {
        session.activeRecallFocusGeneration(for: lessonKey)
    }

    var body: some View {
        LessonRecallView(
            question: question,
            focusGeneration: activeGeneration,
            onAnswer: { _, _ in },
            onFocusApplied: { generation in
                applications.count += 1
                session.acknowledgeRecallFocus(
                    generation: generation,
                    lessonKey: lessonKey
                )
            }
        )
        .id(mountGeneration)
    }
}

private struct RecallFocusTargetHarness: View {
    let question: RecallQuestion
    let persistedWasCorrect: Bool?
    let showsContinue: Bool
    let applications: RecallFocusApplicationCounter

    var body: some View {
        LessonRecallView(
            question: question,
            focusGeneration: 1,
            showsContinue: showsContinue,
            persistedWasCorrect: persistedWasCorrect,
            onAnswer: { _, _ in },
            onFocusApplied: { _ in applications.count += 1 }
        )
    }
}

private final class ProgressFixture {
    let directory: URL
    let progress: ProgressStore

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LessonLearningLoopTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        progress = ProgressStore(
            fileURL: directory.appendingPathComponent("progress.json"),
            now: { Date(timeIntervalSinceReferenceDate: 100) }
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}
