import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class ProgressStoreMigrationTests: XCTestCase {
    private final class ControllableWriter {
        var shouldFail = true

        func write(_ data: Data, to url: URL) throws {
            if shouldFail {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url, options: .atomic)
        }
    }

    private var temporaryDirectory: URL!
    private var progressURL: URL!
    private let fixedDate = Date(timeIntervalSince1970: 1_725_000_000)

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProgressStoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        progressURL = temporaryDirectory.appendingPathComponent("progress.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        progressURL = nil
        temporaryDirectory = nil
    }

    func testBundledLegacyProgressLoadsWithoutRewritingFile() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "legacy-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let originalData = try Data(contentsOf: fixtureURL)
        try originalData.write(to: progressURL)

        let store = makeStore()

        XCTAssertTrue(store.isComplete(2))
        XCTAssertEqual(store.completedLessonIDs, [2])
        XCTAssertEqual(store.stageEvents, [])
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)
    }

    func testKeyedCompletionWritesVersionThree() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "version-2-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let originalData = try Data(contentsOf: fixtureURL)
        try originalData.write(to: progressURL)

        let store = makeStore()
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)

        store.markComplete(.swift(3))
        store.markComplete(3)

        XCTAssertTrue(store.isComplete(.swift(3)))
        XCTAssertEqual(store.completedLessonIDs, [2, 3])
        let saved = try decodeV3(progressURL)
        XCTAssertEqual(saved.version, 3)
        let swiftProgress = try XCTUnwrap(saved.courses[.swiftDevelopment])
        XCTAssertEqual(
            swiftProgress.completedLessonLocalIDs,
            [LessonLocalID(rawValue: "2"), LessonLocalID(rawValue: "3")]
        )
        XCTAssertEqual(swiftProgress.stageEvents.count, 1)
        XCTAssertEqual(
            swiftProgress.stageEvents[0].id,
            ProgressEventID(
                rawValue: "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000"
            )
        )
        XCTAssertEqual(swiftProgress.stageEvents[0].timestamp, Date(timeIntervalSinceReferenceDate: 0))

        let object = try readJSONObject()
        XCTAssertEqual(object["version"] as? Int, 3)
        let courses = try XCTUnwrap(object["courses"] as? [String: Any])
        let swiftObject = try XCTUnwrap(courses[CourseID.swiftDevelopment.rawValue] as? [String: Any])
        let events = try XCTUnwrap(swiftObject["stageEvents"] as? [[String: Any]])
        let timestamp = try XCTUnwrap(events[0]["timestamp"] as? [String: Any])
        XCTAssertEqual(timestamp["iso8601"] as? String, "2001-01-01T00:00:00.000Z")
        XCTAssertEqual(timestamp["referenceSeconds"] as? Double, 0)
    }

    func testKeyedStageMethodsAreIdempotentAndPreserveMigratedEvents() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "version-2-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let originalData = try Data(contentsOf: fixtureURL)
        try originalData.write(to: progressURL)
        var generatedIDs = ["deep-2", "modify-2", "recall-2", "deep-3", "modify-3", "recall-3"]
        let store = makeStore {
            ProgressEventID(rawValue: generatedIDs.removeFirst())
        }

        store.markDeepLessonViewed(.swift(1))
        store.markDeepLessonViewed(.swift(2))
        store.markDeepLessonViewed(.swift(2))
        store.markModifyPassed(.swift(2))
        store.markModifyPassed(.swift(2))
        store.recordRecallAnswer(lessonKey: .swift(2), questionID: "q-2", wasCorrect: false)
        store.recordRecallAnswer(lessonKey: .swift(2), questionID: "q-2", wasCorrect: true)
        store.recordRecallAnswer(lessonKey: .swift(2), questionID: " \n\t ", wasCorrect: true)

        store.markDeepLessonViewed(3)
        store.markModifyPassed(3)
        store.recordRecallAnswer(lessonID: 3, questionID: "q-3", wasCorrect: true)

        XCTAssertEqual(generatedIDs, [])
        XCTAssertTrue(store.hasViewedDeepLesson(.swift(2)))
        XCTAssertTrue(store.hasViewedDeepLesson(2))
        XCTAssertTrue(store.hasPassedModify(.swift(2)))
        XCTAssertTrue(store.hasPassedModify(2))

        let saved = try decodeV3(progressURL)
        let swiftProgress = try XCTUnwrap(saved.courses[.swiftDevelopment])
        XCTAssertEqual(swiftProgress.completedLessonLocalIDs, [LessonLocalID(rawValue: "2")])
        XCTAssertEqual(
            swiftProgress.stageEvents.map(\.id.rawValue),
            [
                "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000",
                "deep-2",
                "modify-2",
                "recall-2",
                "deep-3",
                "modify-3",
                "recall-3"
            ]
        )
        XCTAssertNil(swiftProgress.stageEvents[1].questionID)
        XCTAssertNil(swiftProgress.stageEvents[1].wasCorrect)
        XCTAssertNil(swiftProgress.stageEvents[2].questionID)
        XCTAssertNil(swiftProgress.stageEvents[2].wasCorrect)
        XCTAssertEqual(swiftProgress.stageEvents[3].questionID, "q-2")
        XCTAssertEqual(swiftProgress.stageEvents[3].wasCorrect, false)
        XCTAssertEqual(swiftProgress.stageEvents[3].timestamp, fixedDate)
    }

    func testPresentationStatePersistenceAndReplacement() throws {
        let started = LessonPresentationState(
            status: .started,
            lastSceneID: "scene-2",
            presentationRevision: 4,
            firstStartedAt: fixedDate.addingTimeInterval(-60),
            lastOpenedAt: fixedDate,
            replayCount: 2,
            presentationID: "presentation-v1"
        )
        let store = makeStore()

        store.setPresentationState(started, for: .swift(1))

        XCTAssertEqual(store.presentationState(for: .swift(1)), started)
        XCTAssertEqual(makeStore().presentationState(for: .swift(1)), started)
        let startedWire = try XCTUnwrap(
            try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: progressURL))
                    as? [String: Any]
            )["courses"] as? [String: Any]
        )
        let swiftWire = try XCTUnwrap(startedWire["swift-development"] as? [String: Any])
        let stateWire = try XCTUnwrap(
            try XCTUnwrap(swiftWire["presentationStates"] as? [String: Any])["1"]
                as? [String: Any]
        )
        XCTAssertEqual(stateWire["presentationID"] as? String, "presentation-v1")

        let skipped = LessonPresentationState(
            status: .skipped,
            lastSceneID: nil,
            presentationRevision: 5,
            firstStartedAt: started.firstStartedAt,
            lastOpenedAt: fixedDate.addingTimeInterval(30),
            replayCount: 3,
            presentationID: "presentation-v2"
        )
        store.setPresentationState(skipped, for: .swift(1))

        XCTAssertEqual(store.presentationState(for: .swift(1)), skipped)
        XCTAssertEqual(makeStore().presentationState(for: .swift(1)), skipped)
    }

    func testPresentationStatePersistenceDoesNotInferLegacyCompletion() throws {
        try writeJSONObject(["completedLessonIDs": [1]])

        let store = makeStore()

        XCTAssertTrue(store.isComplete(.swift(1)))
        XCTAssertNil(store.presentationState(for: .swift(1)))
    }

    func testAttemptIDAndCourseResetDeduplicatesOnlyByAttemptID() {
        let store = makeStore()
        let first = makeAttempt(id: "attempt-1", variant: "variant-1")
        let sameIDChangedVariant = makeAttempt(id: "attempt-1", variant: "variant-2")
        let second = makeAttempt(id: "attempt-2", variant: "variant-1")
        let third = makeAttempt(id: "attempt-3", variant: "variant-2")

        store.record(first)
        store.record(sameIDChangedVariant)
        store.record(second)
        store.record(third)

        XCTAssertEqual(
            store.progress(for: .swiftDevelopment).assessmentAttempts,
            [first, second, third]
        )
    }

    func testAttemptIDAndCourseResetDeduplicatesAttemptIDsGlobally() {
        let store = makeStore()
        let first = makeAttempt(
            id: "shared-attempt",
            variant: "swift-original",
            lessonKey: .swift(1)
        )
        let conflictingSecond = makeAttempt(
            id: "shared-attempt",
            variant: "web-conflict",
            lessonKey: LessonKey(
                courseID: .webDevelopment,
                localID: LessonLocalID(rawValue: "html-1")
            )
        )

        store.record(first)
        store.record(conflictingSecond)

        XCTAssertEqual(
            store.progress(for: .swiftDevelopment).assessmentAttempts,
            [first]
        )
        XCTAssertEqual(
            store.progress(for: .webDevelopment).assessmentAttempts,
            []
        )
        XCTAssertEqual(
            makeStore().progress(for: .swiftDevelopment).assessmentAttempts,
            [first]
        )
        XCTAssertEqual(
            makeStore().progress(for: .webDevelopment).assessmentAttempts,
            []
        )
    }

    func testAttemptIDAndCourseResetClearsOnlyAddressedCourse() throws {
        let swiftAttempt = makeAttempt(id: "swift-attempt", variant: "swift-v1")
        let webKey = LessonKey(
            courseID: .webDevelopment,
            localID: LessonLocalID(rawValue: "html-1")
        )
        let webAttempt = makeAttempt(
            id: "web-attempt",
            variant: "web-v1",
            lessonKey: webKey
        )
        let presentation = LessonPresentationState(
            status: .completed,
            lastSceneID: "scene-final",
            presentationRevision: 2,
            firstStartedAt: fixedDate,
            lastOpenedAt: fixedDate,
            replayCount: 1
        )
        let swiftProgress = CourseProgressDocument(
            completedLessonLocalIDs: [LessonLocalID(rawValue: "1")],
            stageEvents: [
                CourseStageEvent(
                    id: ProgressEventID(rawValue: "swift-event"),
                    lessonLocalID: LessonLocalID(rawValue: "1"),
                    kind: .modifyPassed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                )
            ],
            presentationStates: [LessonLocalID(rawValue: "1"): presentation],
            assessmentAttempts: [swiftAttempt],
            reviews: [makeReview(id: "swift-review", satisfyingAttemptID: swiftAttempt.id)],
            lastLessonLocalID: LessonLocalID(rawValue: "1"),
            readinessSnapshots: [makeReadiness(attemptID: swiftAttempt.id)]
        )
        let webProgress = CourseProgressDocument(
            completedLessonLocalIDs: [webKey.localID],
            stageEvents: [
                CourseStageEvent(
                    id: ProgressEventID(rawValue: "web-event"),
                    lessonLocalID: webKey.localID,
                    kind: .deepLessonViewed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                )
            ],
            presentationStates: [webKey.localID: presentation],
            assessmentAttempts: [webAttempt],
            reviews: [makeReview(id: "web-review", satisfyingAttemptID: webAttempt.id)],
            lastLessonLocalID: webKey.localID,
            readinessSnapshots: [makeReadiness(attemptID: webAttempt.id)]
        )
        try writeV3(
            ProgressDocument(
                version: 3,
                courses: [
                    .swiftDevelopment: swiftProgress,
                    .webDevelopment: webProgress
                ]
            )
        )
        let store = makeStore()

        store.reset(courseID: .swiftDevelopment)

        XCTAssertEqual(store.progress(for: .swiftDevelopment), CourseProgressDocument())
        XCTAssertEqual(store.progress(for: .webDevelopment), webProgress)
        XCTAssertEqual(makeStore().progress(for: .webDevelopment), webProgress)

        store.record(swiftAttempt)
        store.reset()

        XCTAssertEqual(store.progress(for: .swiftDevelopment), CourseProgressDocument())
        XCTAssertEqual(store.progress(for: .webDevelopment), webProgress)
    }

    func testMeaningfulActivityAndLastLessonTracksAcceptedMutations() throws {
        let store = makeStore()

        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))
        _ = store.progress(for: .swiftDevelopment)
        _ = store.presentationState(for: .swift(99))
        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))
        XCTAssertFalse(FileManager.default.fileExists(atPath: progressURL.path))

        let notStarted = LessonPresentationState(
            status: .notStarted,
            lastSceneID: nil,
            presentationRevision: 1,
            firstStartedAt: nil,
            lastOpenedAt: nil,
            replayCount: 0
        )
        store.setPresentationState(notStarted, for: .swift(1))
        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))

        store.markComplete(.swift(2))
        XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(2))
        store.reset()
        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))

        store.markDeepLessonViewed(.swift(3))
        XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(3))
        store.reset()

        for (status, lessonID) in [
            (PresentationStatus.started, 4),
            (.skipped, 5),
            (.completed, 6)
        ] {
            store.setPresentationState(
                LessonPresentationState(
                    status: status,
                    lastSceneID: "scene-\(lessonID)",
                    presentationRevision: 1,
                    firstStartedAt: fixedDate,
                    lastOpenedAt: fixedDate,
                    replayCount: 0
                ),
                for: .swift(lessonID)
            )
            XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
            XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(lessonID))
            store.reset()
        }

        let attempt = makeAttempt(id: "activity-attempt", variant: "v1", lessonKey: .swift(7))
        store.record(attempt)
        XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(7))
        store.reset()

        store.recordSavedWorkspaceActivity(for: .swift(8))
        XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(8))
        XCTAssertEqual(makeStore().lastLessonKey(in: .swiftDevelopment), .swift(8))
        store.reset()
        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))
    }

    func testMeaningfulActivityAndLastLessonValidatesSatisfiedReviews() throws {
        let satisfyingAttempt = makeAttempt(
            id: "satisfying-attempt",
            variant: "v1",
            lessonKey: .swift(12)
        )
        try writeV3(
            ProgressDocument(
                version: 3,
                courses: [
                    .swiftDevelopment: CourseProgressDocument(
                        assessmentAttempts: [satisfyingAttempt],
                        reviews: [
                            makeReview(
                                id: "satisfied-review",
                                satisfyingAttemptID: satisfyingAttempt.id
                            )
                        ]
                    )
                ]
            )
        )
        var store = makeStore()

        XCTAssertTrue(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertEqual(store.lastLessonKey(in: .swiftDevelopment), .swift(12))

        try writeV3(
            ProgressDocument(
                version: 3,
                courses: [
                    .swiftDevelopment: CourseProgressDocument(
                        reviews: [
                            makeReview(
                                id: "unresolved-review",
                                satisfyingAttemptID: AttemptID(rawValue: "missing-attempt")
                            ),
                            makeReview(id: "scheduled-review", satisfyingAttemptID: nil)
                        ]
                    ),
                    .webDevelopment: CourseProgressDocument(
                        assessmentAttempts: [
                            makeAttempt(
                                id: "missing-attempt",
                                variant: "web-v1",
                                lessonKey: LessonKey(
                                    courseID: .webDevelopment,
                                    localID: LessonLocalID(rawValue: "web-1")
                                )
                            )
                        ]
                    )
                ]
            )
        )
        store = makeStore()

        XCTAssertFalse(store.hasMeaningfulActivity(in: .swiftDevelopment))
        XCTAssertNil(store.lastLessonKey(in: .swiftDevelopment))
    }

    func testAtomicWriteAndRetryCreatesParentAndRetainsFailedSave() throws {
        let nestedURL = temporaryDirectory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("deeper", isDirectory: true)
            .appendingPathComponent("progress.json", isDirectory: false)
        let productionStore = ProgressStore(
            fileURL: nestedURL,
            now: { self.fixedDate }
        )

        productionStore.markComplete(.swift(1))

        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedURL.path))
        XCTAssertEqual(
            try decodeV3(nestedURL).courses[.swiftDevelopment]?.completedLessonLocalIDs,
            [LessonLocalID(rawValue: "1")]
        )

        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "version-2-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let originalData = try Data(contentsOf: fixtureURL)
        try originalData.write(to: progressURL)
        let writer = ControllableWriter()
        var eventIDCalls = 0
        let store = makeStore(
            makeEventID: {
                eventIDCalls += 1
                return ProgressEventID(rawValue: "unexpected-event-id")
            },
            writeData: writer.write
        )

        store.markComplete(.swift(3))

        XCTAssertTrue(store.isComplete(.swift(3)))
        XCTAssertNotNil(store.saveError)
        XCTAssertEqual(eventIDCalls, 0)
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)

        writer.shouldFail = false
        store.retrySave()

        XCTAssertNil(store.saveError)
        XCTAssertEqual(eventIDCalls, 0)
        let retained = try decodeV3(progressURL)
        XCTAssertEqual(
            retained.courses[.swiftDevelopment]?.completedLessonLocalIDs,
            [LessonLocalID(rawValue: "2"), LessonLocalID(rawValue: "3")]
        )
        XCTAssertEqual(
            retained.courses[.swiftDevelopment]?.stageEvents.first?.id.rawValue,
            "legacy-v2|swift-development|1|deepLessonViewed|-|978307200000"
        )
    }

    func testUnsupportedAndCorruptBlockEveryMutation() throws {
        let cases: [(name: String, data: Data)] = [
            ("future", Data(#"{ "version":4,"payload":{"future":true} }"#.utf8)),
            ("corrupt", Data(#"{ "version":3,"courses":"not-an-object" }"#.utf8))
        ]
        let presentation = LessonPresentationState(
            status: .started,
            lastSceneID: "blocked-scene",
            presentationRevision: 1,
            firstStartedAt: fixedDate,
            lastOpenedAt: fixedDate,
            replayCount: 0
        )
        let attempt = makeAttempt(
            id: "blocked-attempt",
            variant: "blocked-v1",
            lessonKey: .swift(9)
        )

        for testCase in cases {
            try testCase.data.write(to: progressURL, options: .atomic)
            var eventIDCalls = 0
            var writeCalls = 0
            let store = makeStore(
                makeEventID: {
                    eventIDCalls += 1
                    return ProgressEventID(rawValue: "blocked-event")
                },
                writeData: { _, _ in writeCalls += 1 }
            )
            let originalSwiftProgress = store.progress(for: .swiftDevelopment)
            let originalWebProgress = store.progress(for: .webDevelopment)
            let originalCompleted = store.completedLessonIDs
            let originalEvents = store.stageEvents
            let originalReadOnly = store.isReadOnlyForUnsupportedVersion
            let originalLoadError = store.loadError
            let originalSaveError = store.saveError

            store.markComplete(.swift(1))
            store.markComplete(2)
            store.markDeepLessonViewed(.swift(1))
            store.markDeepLessonViewed(2)
            store.markModifyPassed(.swift(1))
            store.markModifyPassed(2)
            store.recordRecallAnswer(
                lessonKey: .swift(1),
                questionID: "blocked-keyed",
                wasCorrect: true
            )
            store.recordRecallAnswer(
                lessonID: 2,
                questionID: "blocked-integer",
                wasCorrect: false
            )
            store.setPresentationState(presentation, for: .swift(1))
            store.record(attempt)
            store.recordSavedWorkspaceActivity(for: .swift(1))
            store.reset(courseID: .swiftDevelopment)
            store.reset()
            store.retrySave()

            XCTAssertEqual(store.progress(for: .swiftDevelopment), originalSwiftProgress, testCase.name)
            XCTAssertEqual(store.progress(for: .webDevelopment), originalWebProgress, testCase.name)
            XCTAssertEqual(store.completedLessonIDs, originalCompleted, testCase.name)
            XCTAssertEqual(store.stageEvents, originalEvents, testCase.name)
            XCTAssertEqual(store.isReadOnlyForUnsupportedVersion, originalReadOnly, testCase.name)
            XCTAssertEqual(store.loadError, originalLoadError, testCase.name)
            XCTAssertEqual(store.saveError, originalSaveError, testCase.name)
            XCTAssertEqual(eventIDCalls, 0, testCase.name)
            XCTAssertEqual(writeCalls, 0, testCase.name)
            XCTAssertEqual(try Data(contentsOf: progressURL), testCase.data, testCase.name)
        }
    }

    func testDeepAndModifyEventsAreIdempotentAndUseInjectedClock() {
        let store = makeStore()

        store.markDeepLessonViewed(4)
        store.markDeepLessonViewed(4)
        store.markModifyPassed(4)
        store.markModifyPassed(4)

        XCTAssertEqual(
            store.stageEvents,
            [
                LessonStageEvent(
                    lessonID: 4,
                    kind: .deepLessonViewed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                ),
                LessonStageEvent(
                    lessonID: 4,
                    kind: .modifyPassed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                )
            ]
        )
    }

    func testRecallAnswerIsIdempotentPerQuestionAndFirstCorrectnessWins() {
        let store = makeStore()

        store.recordRecallAnswer(lessonID: 5, questionID: "q-1", wasCorrect: false)
        store.recordRecallAnswer(lessonID: 5, questionID: "q-1", wasCorrect: true)
        store.recordRecallAnswer(lessonID: 5, questionID: "q-2", wasCorrect: true)

        XCTAssertEqual(store.stageEvents.count, 2)
        XCTAssertEqual(store.stageEvents[0].questionID, "q-1")
        XCTAssertEqual(store.stageEvents[0].wasCorrect, false)
        XCTAssertEqual(store.stageEvents[0].timestamp, fixedDate)
        XCTAssertEqual(store.stageEvents[1].questionID, "q-2")
        XCTAssertEqual(store.stageEvents[1].wasCorrect, true)
    }

    func testEmptyRecallQuestionIDIsRejectedWithoutWriting() {
        let store = makeStore()

        store.recordRecallAnswer(lessonID: 6, questionID: " \n\t ", wasCorrect: true)

        XCTAssertEqual(store.stageEvents, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: progressURL.path))
    }

    func testInvalidDecodedEventMetadataIsDroppedWhileValidEventsAndCompletionRemain() throws {
        try writeJSONObject([
            "version": 2,
            "completedLessonIDs": [8],
            "stageEvents": [
                eventJSONObject(lessonID: 8, kind: "deepLessonViewed"),
                eventJSONObject(
                    lessonID: 8,
                    kind: "modifyPassed",
                    questionID: "not-allowed"
                ),
                eventJSONObject(
                    lessonID: 8,
                    kind: "deepLessonViewed",
                    wasCorrect: true
                ),
                eventJSONObject(
                    lessonID: 8,
                    kind: "recallAnswered",
                    questionID: "valid-recall",
                    wasCorrect: false
                ),
                eventJSONObject(
                    lessonID: 8,
                    kind: "recallAnswered",
                    wasCorrect: true
                ),
                eventJSONObject(
                    lessonID: 8,
                    kind: "recallAnswered",
                    questionID: "   ",
                    wasCorrect: true
                ),
                eventJSONObject(
                    lessonID: 8,
                    kind: "recallAnswered",
                    questionID: "missing-correctness"
                )
            ]
        ])

        let store = makeStore()

        XCTAssertEqual(store.completedLessonIDs, [8])
        XCTAssertEqual(
            store.stageEvents,
            [
                LessonStageEvent(
                    lessonID: 8,
                    kind: .deepLessonViewed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                ),
                LessonStageEvent(
                    lessonID: 8,
                    kind: .recallAnswered,
                    timestamp: fixedDate,
                    questionID: "valid-recall",
                    wasCorrect: false
                )
            ]
        )
    }

    func testMixedVersionTwoEventsDropOnlyUnknownAndMalformedElements() throws {
        let validEvent = eventJSONObject(lessonID: 14, kind: "deepLessonViewed")
        var malformedEvent = eventJSONObject(lessonID: 14, kind: "modifyPassed")
        malformedEvent.removeValue(forKey: "timestamp")
        try writeJSONObject([
            "version": 2,
            "completedLessonIDs": [1, 3],
            "stageEvents": [
                validEvent,
                eventJSONObject(lessonID: 14, kind: "futureStageKind"),
                malformedEvent,
                [
                    "lessonID": "not-an-integer",
                    "kind": "modifyPassed",
                    "timestamp": fixedDate.timeIntervalSinceReferenceDate
                ]
            ]
        ])

        let store = makeStore()

        XCTAssertEqual(store.completedLessonIDs, [1, 3])
        XCTAssertEqual(
            store.stageEvents,
            [
                LessonStageEvent(
                    lessonID: 14,
                    kind: .deepLessonViewed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                )
            ]
        )
    }

    func testFutureVersionLoadsReadOnlyAndEveryMutationLeavesStateAndBytesUnchanged() throws {
        try writeJSONObject([
            "version": 4,
            "completedLessonIDs": [21, 23],
            "stageEvents": [
                eventJSONObject(lessonID: 21, kind: "deepLessonViewed")
            ]
        ])
        let originalData = try Data(contentsOf: progressURL)
        let store = makeStore()
        let originalCompletedLessonIDs = store.completedLessonIDs
        let originalStageEvents = store.stageEvents

        store.markComplete(25)
        store.markDeepLessonViewed(23)
        store.markModifyPassed(21)
        store.recordRecallAnswer(lessonID: 21, questionID: "future-q", wasCorrect: true)
        store.reset()

        XCTAssertEqual(originalCompletedLessonIDs, [])
        XCTAssertEqual(originalStageEvents.count, 0)
        XCTAssertEqual(store.completedLessonIDs, originalCompletedLessonIDs)
        XCTAssertEqual(store.stageEvents, originalStageEvents)
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)
    }

    func testFutureVersionWithIncompatiblePayloadIsReadOnlyBeforePayloadDecode() throws {
        try writeJSONObject([
            "version": 4,
            "completedLessonIDs": "future-completion-shape",
            "stageEvents": ["future-event-shape"]
        ])
        let originalData = try Data(contentsOf: progressURL)
        let store = makeStore()

        XCTAssertTrue(store.isReadOnlyForUnsupportedVersion)
        XCTAssertEqual(store.completedLessonIDs, [])
        XCTAssertEqual(store.stageEvents, [])

        store.markComplete(41)
        store.markDeepLessonViewed(41)
        store.markModifyPassed(41)
        store.recordRecallAnswer(lessonID: 41, questionID: "future-q", wasCorrect: true)
        store.reset()

        XCTAssertTrue(store.isReadOnlyForUnsupportedVersion)
        XCTAssertEqual(store.completedLessonIDs, [])
        XCTAssertEqual(store.stageEvents, [])
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)
    }

    func testFutureAndCorruptLoadStatePreserveBytes() throws {
        let futureData = Data(#"{ "version":4,"payload":"future-shape" }"#.utf8)
        try futureData.write(to: progressURL)

        let futureStore = makeStore()

        XCTAssertTrue(futureStore.isReadOnlyForUnsupportedVersion)
        XCTAssertNil(futureStore.loadError)
        XCTAssertEqual(futureStore.completedLessonIDs, [])
        XCTAssertEqual(futureStore.stageEvents, [])
        XCTAssertEqual(futureStore.progress(for: .swiftDevelopment), CourseProgressDocument())
        XCTAssertEqual(try Data(contentsOf: progressURL), futureData)

        let corruptData = Data(#"{ "version":3,"courses":"not-an-object" }"#.utf8)
        try corruptData.write(to: progressURL)

        let corruptStore = makeStore()

        XCTAssertFalse(corruptStore.isReadOnlyForUnsupportedVersion)
        XCTAssertFalse(try XCTUnwrap(corruptStore.loadError).isEmpty)
        XCTAssertEqual(corruptStore.completedLessonIDs, [])
        XCTAssertEqual(corruptStore.stageEvents, [])
        XCTAssertEqual(corruptStore.progress(for: .swiftDevelopment), CourseProgressDocument())
        XCTAssertEqual(try Data(contentsOf: progressURL), corruptData)
    }

    func testDuplicateDecodedEventsKeepFirstLogicalEventAndMetadata() throws {
        let laterDate = fixedDate.addingTimeInterval(60)
        try writeJSONObject([
            "version": 2,
            "completedLessonIDs": [],
            "stageEvents": [
                eventJSONObject(lessonID: 31, kind: "deepLessonViewed"),
                eventJSONObject(
                    lessonID: 31,
                    kind: "deepLessonViewed",
                    timestamp: laterDate
                ),
                eventJSONObject(lessonID: 31, kind: "modifyPassed"),
                eventJSONObject(
                    lessonID: 31,
                    kind: "modifyPassed",
                    timestamp: laterDate
                ),
                eventJSONObject(
                    lessonID: 31,
                    kind: "recallAnswered",
                    questionID: "q-1",
                    wasCorrect: false
                ),
                eventJSONObject(
                    lessonID: 31,
                    kind: "recallAnswered",
                    timestamp: laterDate,
                    questionID: "q-1",
                    wasCorrect: true
                ),
                eventJSONObject(
                    lessonID: 31,
                    kind: "recallAnswered",
                    timestamp: laterDate,
                    questionID: "q-2",
                    wasCorrect: true
                ),
                eventJSONObject(
                    lessonID: 32,
                    kind: "deepLessonViewed",
                    timestamp: laterDate
                )
            ]
        ])

        let store = makeStore()

        XCTAssertEqual(
            store.stageEvents,
            [
                LessonStageEvent(
                    lessonID: 31,
                    kind: .deepLessonViewed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                ),
                LessonStageEvent(
                    lessonID: 31,
                    kind: .modifyPassed,
                    timestamp: fixedDate,
                    questionID: nil,
                    wasCorrect: nil
                ),
                LessonStageEvent(
                    lessonID: 31,
                    kind: .recallAnswered,
                    timestamp: fixedDate,
                    questionID: "q-1",
                    wasCorrect: false
                ),
                LessonStageEvent(
                    lessonID: 31,
                    kind: .recallAnswered,
                    timestamp: laterDate,
                    questionID: "q-2",
                    wasCorrect: true
                ),
                LessonStageEvent(
                    lessonID: 32,
                    kind: .deepLessonViewed,
                    timestamp: laterDate,
                    questionID: nil,
                    wasCorrect: nil
                )
            ]
        )
    }

    func testVersionTwoLoadsKeyedFieldsWithoutRewriting() throws {
        let laterDate = fixedDate.addingTimeInterval(60)
        try writeJSONObject([
            "version": 2,
            "completedLessonIDs": [9],
            "stageEvents": [
                eventJSONObject(lessonID: 9, kind: "deepLessonViewed"),
                eventJSONObject(
                    lessonID: 9,
                    kind: "recallAnswered",
                    timestamp: laterDate,
                    questionID: "question-9",
                    wasCorrect: false
                ),
                eventJSONObject(lessonID: 10, kind: "modifyPassed")
            ]
        ])
        let originalData = try Data(contentsOf: progressURL)

        let store = makeStore()

        XCTAssertTrue(store.isComplete(.swift(9)))
        XCTAssertTrue(store.hasViewedDeepLesson(.swift(9)))
        XCTAssertTrue(store.hasPassedModify(.swift(10)))
        XCTAssertEqual(store.completedLessonIDs, [9])
        XCTAssertEqual(store.stageEvents.count, 3)
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)

        store.markComplete(.swift(10))

        let saved = try decodeV3(progressURL)
        XCTAssertEqual(saved.version, 3)
        XCTAssertEqual(saved.courses.count, 1)
        let savedSwift = try XCTUnwrap(saved.courses[.swiftDevelopment])
        XCTAssertEqual(
            savedSwift.completedLessonLocalIDs,
            [LessonLocalID(rawValue: "9"), LessonLocalID(rawValue: "10")]
        )
        XCTAssertEqual(savedSwift.stageEvents.count, 3)

        let reopenedSwift = makeStore().progress(for: .swiftDevelopment)
        XCTAssertEqual(reopenedSwift, savedSwift)

        XCTAssertEqual(
            reopenedSwift.stageEvents[0].id,
            ProgressEventID(
                rawValue: "legacy-v2|swift-development|9|deepLessonViewed|-|1725000000000"
            )
        )
        XCTAssertEqual(reopenedSwift.stageEvents[0].timestamp, fixedDate)
        XCTAssertEqual(reopenedSwift.stageEvents[0].lessonLocalID, LessonLocalID(rawValue: "9"))
        XCTAssertEqual(reopenedSwift.stageEvents[0].kind, .deepLessonViewed)
        XCTAssertNil(reopenedSwift.stageEvents[0].questionID)
        XCTAssertNil(reopenedSwift.stageEvents[0].wasCorrect)

        XCTAssertEqual(
            reopenedSwift.stageEvents[1].id,
            ProgressEventID(
                rawValue: "legacy-v2|swift-development|9|recallAnswered|question-9|1725000060000"
            )
        )
        XCTAssertEqual(reopenedSwift.stageEvents[1].timestamp, laterDate)
        XCTAssertEqual(reopenedSwift.stageEvents[1].lessonLocalID, LessonLocalID(rawValue: "9"))
        XCTAssertEqual(reopenedSwift.stageEvents[1].kind, .recallAnswered)
        XCTAssertEqual(reopenedSwift.stageEvents[1].questionID, "question-9")
        XCTAssertEqual(reopenedSwift.stageEvents[1].wasCorrect, false)

        XCTAssertEqual(
            reopenedSwift.stageEvents[2].id,
            ProgressEventID(
                rawValue: "legacy-v2|swift-development|10|modifyPassed|-|1725000000000"
            )
        )
        XCTAssertEqual(reopenedSwift.stageEvents[2].timestamp, fixedDate)
        XCTAssertEqual(reopenedSwift.stageEvents[2].lessonLocalID, LessonLocalID(rawValue: "10"))
        XCTAssertEqual(reopenedSwift.stageEvents[2].kind, .modifyPassed)
        XCTAssertNil(reopenedSwift.stageEvents[2].questionID)
        XCTAssertNil(reopenedSwift.stageEvents[2].wasCorrect)
    }

    func testVersionThreeReloadPreservesEveryFieldWithoutRewriting() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "version-3-progress",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let originalData = try Data(contentsOf: fixtureURL)
        try originalData.write(to: progressURL)

        let store = makeStore()
        let swiftProgress = store.progress(for: .swiftDevelopment)

        XCTAssertEqual(swiftProgress.completedLessonLocalIDs, [LessonLocalID(rawValue: "1")])
        XCTAssertEqual(swiftProgress.stageEvents.count, 1)
        XCTAssertEqual(swiftProgress.stageEvents[0].id, ProgressEventID(rawValue: "event-1"))
        XCTAssertEqual(swiftProgress.stageEvents[0].lessonLocalID, LessonLocalID(rawValue: "1"))
        XCTAssertEqual(swiftProgress.stageEvents[0].kind, .recallAnswered)
        XCTAssertEqual(swiftProgress.stageEvents[0].timestamp, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(swiftProgress.stageEvents[0].questionID, "recall-1")
        XCTAssertEqual(swiftProgress.stageEvents[0].wasCorrect, false)

        let presentation = try XCTUnwrap(
            swiftProgress.presentationStates[LessonLocalID(rawValue: "1")]
        )
        XCTAssertEqual(presentation.status, .started)
        XCTAssertEqual(presentation.lastSceneID, "scene-1")
        XCTAssertEqual(presentation.presentationRevision, 1)
        XCTAssertEqual(presentation.firstStartedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(presentation.lastOpenedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(presentation.replayCount, 1)

        XCTAssertEqual(swiftProgress.assessmentAttempts.count, 1)
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].id, AttemptID(rawValue: "attempt-1"))
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].lessonKey, .swift(1))
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].activityID, ActivityID(rawValue: "swift.lesson-1.ai-review"))
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].itemVariantID, ItemVariantID(rawValue: "v1"))
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].conceptIDs, [ConceptID(rawValue: "swift.lesson-1.string-literal")])
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].objectiveMappings, [
            ObjectiveMapping(
                conceptID: ConceptID(rawValue: "swift.lesson-1.string-literal"),
                objectiveSetID: ObjectiveSetID(rawValue: "swift-associate-2024"),
                objectiveID: ObjectiveID(rawValue: "3.1")
            )
        ])
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].scaffoldLevel, .none)
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].result, .passed)
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].contentRevision, 1)
        XCTAssertFalse(swiftProgress.assessmentAttempts[0].wasPreviouslySeen)
        XCTAssertEqual(swiftProgress.assessmentAttempts[0].submittedAt, Date(timeIntervalSince1970: 100))

        XCTAssertEqual(swiftProgress.reviews.count, 1)
        XCTAssertEqual(swiftProgress.reviews[0].id, ReviewID(rawValue: "review-1"))
        XCTAssertEqual(swiftProgress.reviews[0].conceptID, ConceptID(rawValue: "swift.lesson-1.string-literal"))
        XCTAssertEqual(swiftProgress.reviews[0].createdAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(swiftProgress.reviews[0].dueAt, Date(timeIntervalSince1970: 300))
        XCTAssertEqual(swiftProgress.reviews[0].policyVersion, MasteryPolicyVersion(rawValue: "policy-1"))
        XCTAssertEqual(swiftProgress.reviews[0].sourceEvidenceAttemptIDs, [AttemptID(rawValue: "attempt-1")])
        XCTAssertEqual(swiftProgress.reviews[0].satisfyingAttemptID, AttemptID(rawValue: "attempt-1"))
        XCTAssertEqual(swiftProgress.lastLessonLocalID, LessonLocalID(rawValue: "1"))

        XCTAssertEqual(swiftProgress.readinessSnapshots.count, 1)
        XCTAssertEqual(swiftProgress.readinessSnapshots[0].objectiveSetID, ObjectiveSetID(rawValue: "swift-associate-2024"))
        XCTAssertEqual(swiftProgress.readinessSnapshots[0].policyVersion, MasteryPolicyVersion(rawValue: "policy-1"))
        XCTAssertEqual(swiftProgress.readinessSnapshots[0].calculatedAt, Date(timeIntervalSince1970: 400))
        XCTAssertEqual(swiftProgress.readinessSnapshots[0].evidenceAttemptIDs, [AttemptID(rawValue: "attempt-1")])
        XCTAssertTrue(store.isComplete(.swift(1)))
        XCTAssertEqual(try Data(contentsOf: progressURL), originalData)
    }

    func testMarkCompletePreservesStageEvents() {
        let store = makeStore()
        store.markDeepLessonViewed(10)
        let eventsBeforeCompletion = store.stageEvents

        store.markComplete(10)

        XCTAssertTrue(store.isComplete(10))
        XCTAssertEqual(store.completedCount, 1)
        XCTAssertEqual(store.stageEvents, eventsBeforeCompletion)
        XCTAssertEqual(makeStore().stageEvents, eventsBeforeCompletion)
    }

    func testResetClearsCompletionAndStageEventsAndPersistsVersionThree() throws {
        let store = makeStore()
        store.markComplete(11)
        store.markDeepLessonViewed(11)
        store.recordRecallAnswer(lessonID: 11, questionID: "question-11", wasCorrect: false)

        store.reset()

        XCTAssertEqual(store.completedLessonIDs, [])
        XCTAssertEqual(store.stageEvents, [])
        let reopenedStore = makeStore()
        XCTAssertEqual(reopenedStore.completedLessonIDs, [])
        XCTAssertEqual(reopenedStore.stageEvents, [])
        let saved = try decodeV3(progressURL)
        XCTAssertEqual(saved.version, 3)
        XCTAssertEqual(saved.courses[.swiftDevelopment], CourseProgressDocument())
    }

    func testStageQueriesReflectMatchingLessonEvents() {
        let store = makeStore()
        store.markDeepLessonViewed(12)
        store.markModifyPassed(13)

        XCTAssertTrue(store.hasViewedDeepLesson(12))
        XCTAssertFalse(store.hasViewedDeepLesson(13))
        XCTAssertTrue(store.hasPassedModify(13))
        XCTAssertFalse(store.hasPassedModify(12))
    }

    private func makeStore(
        makeEventID: @escaping () -> ProgressEventID = {
            ProgressEventID(rawValue: "new-event-id")
        },
        writeData: @escaping (Data, URL) throws -> Void = ProgressStore.atomicWrite
    ) -> ProgressStore {
        ProgressStore(
            fileURL: progressURL,
            now: { self.fixedDate },
            makeEventID: makeEventID,
            writeData: writeData
        )
    }

    private func decodeV3(_ url: URL) throws -> ProgressDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = ProgressDateCoding.decodingStrategy
        return try decoder.decode(ProgressDocument.self, from: Data(contentsOf: url))
    }

    private func writeV3(_ document: ProgressDocument) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = ProgressDateCoding.encodingStrategy
        try encoder.encode(document).write(to: progressURL, options: .atomic)
    }

    private func makeAttempt(
        id: String,
        variant: String,
        lessonKey: LessonKey = .swift(1)
    ) -> AssessmentAttempt {
        AssessmentAttempt(
            id: AttemptID(rawValue: id),
            lessonKey: lessonKey,
            activityID: ActivityID(rawValue: "activity-\(id)"),
            itemVariantID: ItemVariantID(rawValue: variant),
            conceptIDs: [ConceptID(rawValue: "concept-1")],
            objectiveMappings: [
                ObjectiveMapping(
                    conceptID: ConceptID(rawValue: "concept-1"),
                    objectiveSetID: ObjectiveSetID(rawValue: "objective-set-1"),
                    objectiveID: ObjectiveID(rawValue: "objective-1")
                )
            ],
            scaffoldLevel: .conceptReminder,
            result: .passed,
            contentRevision: 3,
            wasPreviouslySeen: true,
            submittedAt: fixedDate
        )
    }

    private func makeReview(
        id: String,
        satisfyingAttemptID: AttemptID?
    ) -> ReviewRecord {
        ReviewRecord(
            id: ReviewID(rawValue: id),
            conceptID: ConceptID(rawValue: "concept-1"),
            createdAt: fixedDate,
            dueAt: fixedDate.addingTimeInterval(60),
            policyVersion: MasteryPolicyVersion(rawValue: "policy-1"),
            sourceEvidenceAttemptIDs: satisfyingAttemptID.map { [$0] } ?? [],
            satisfyingAttemptID: satisfyingAttemptID
        )
    }

    private func makeReadiness(attemptID: AttemptID) -> ReadinessSnapshot {
        ReadinessSnapshot(
            objectiveSetID: ObjectiveSetID(rawValue: "objective-set-1"),
            policyVersion: MasteryPolicyVersion(rawValue: "policy-1"),
            calculatedAt: fixedDate,
            evidenceAttemptIDs: [attemptID]
        )
    }

    private func writeJSONObject(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try data.write(to: progressURL, options: .atomic)
    }

    private func readJSONObject() throws -> [String: Any] {
        let data = try Data(contentsOf: progressURL)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    private func eventJSONObject(
        lessonID: Int,
        kind: String,
        timestamp: Date? = nil,
        questionID: String? = nil,
        wasCorrect: Bool? = nil
    ) -> [String: Any] {
        var event: [String: Any] = [
            "lessonID": lessonID,
            "kind": kind,
            "timestamp": (timestamp ?? fixedDate).timeIntervalSinceReferenceDate
        ]
        if let questionID {
            event["questionID"] = questionID
        }
        if let wasCorrect {
            event["wasCorrect"] = wasCorrect
        }
        return event
    }
}
