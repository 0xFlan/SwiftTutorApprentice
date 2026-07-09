import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class ProgressStoreMigrationTests: XCTestCase {
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

    func testFirstMutationUpgradesLegacyProgressAndPreservesCompletedIDs() throws {
        try writeJSONObject(["completedLessonIDs": [1, 3]])

        let store = makeStore()
        store.markDeepLessonViewed(7)

        let saved = try readJSONObject()
        XCTAssertEqual(saved["version"] as? Int, 2)
        XCTAssertEqual(saved["completedLessonIDs"] as? [Int], [1, 3])
        let events = try XCTUnwrap(saved["stageEvents"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["lessonID"] as? Int, 7)
        XCTAssertEqual(events[0]["kind"] as? String, "deepLessonViewed")
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

    func testVersionTwoReloadPreservesEveryEventField() {
        let store = makeStore()
        store.markComplete(9)
        store.markDeepLessonViewed(9)
        store.markModifyPassed(9)
        store.recordRecallAnswer(lessonID: 9, questionID: "question-9", wasCorrect: true)

        let reopenedStore = makeStore()

        XCTAssertEqual(reopenedStore.completedLessonIDs, [9])
        XCTAssertEqual(reopenedStore.stageEvents, store.stageEvents)
        XCTAssertEqual(reopenedStore.stageEvents.last?.lessonID, 9)
        XCTAssertEqual(reopenedStore.stageEvents.last?.kind, .recallAnswered)
        XCTAssertEqual(reopenedStore.stageEvents.last?.timestamp, fixedDate)
        XCTAssertEqual(reopenedStore.stageEvents.last?.questionID, "question-9")
        XCTAssertEqual(reopenedStore.stageEvents.last?.wasCorrect, true)
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

    func testResetClearsCompletionAndStageEventsAndPersistsVersionTwo() throws {
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
        XCTAssertEqual(try readJSONObject()["version"] as? Int, 2)
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

    private func makeStore() -> ProgressStore {
        ProgressStore(fileURL: progressURL, now: { self.fixedDate })
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
        questionID: String? = nil,
        wasCorrect: Bool? = nil
    ) -> [String: Any] {
        var event: [String: Any] = [
            "lessonID": lessonID,
            "kind": kind,
            "timestamp": fixedDate.timeIntervalSinceReferenceDate
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
