import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class LessonStoreMigrationTests: XCTestCase {
    private var fixtureDirectory: URL!
    private var fixtureURL: URL!

    override func setUpWithError() throws {
        fixtureDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LessonStoreMigrationTests-\(UUID().uuidString)", isDirectory: true)
        fixtureURL = fixtureDirectory.appendingPathComponent("lessons.json", isDirectory: false)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        if let fixtureDirectory {
            try? FileManager.default.removeItem(at: fixtureDirectory)
        }
        fixtureURL = nil
        fixtureDirectory = nil
    }

    func testCompatibleBuiltInLessonReceivesOnlyStockDeepContent() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )
        let secondStockLesson = Curriculum.defaultLessons[1]

        var editedLesson = stockLesson
        editedLesson.title = "My printing title"
        editedLesson.goal = "My printing goal"
        editedLesson.teaches = ["my second topic", "my first topic"]
        editedLesson.glossaryTerms = ["value", "String"]
        editedLesson.syntaxTokens = [
            SyntaxToken(id: 99, display: "custom", explanation: "My syntax token")
        ]
        editedLesson.syntaxWhy = "My explanation of why this syntax exists"
        editedLesson.expectedOutput = "My output"
        editedLesson.successMarkers = ["second marker", "first marker"]
        editedLesson.successMessage = "My success message"
        editedLesson.hint = "My hint"
        editedLesson.deepContent = nil

        try writeLessons([secondStockLesson, editedLesson])

        let store = LessonStore(
            fileURL: fixtureURL,
            defaults: [stockLesson, secondStockLesson]
        )

        var expectedEditedLesson = editedLesson
        expectedEditedLesson.deepContent = stockLesson.deepContent
        XCTAssertEqual(store.lessons.map(\.id), [secondStockLesson.id, editedLesson.id])
        XCTAssertEqual(store.lessons[0], secondStockLesson)
        XCTAssertEqual(store.lessons[1], expectedEditedLesson)

        let persistedLessons = try readLessons()
        XCTAssertEqual(persistedLessons.map(\.id), [secondStockLesson.id, editedLesson.id])
        XCTAssertEqual(persistedLessons[0], secondStockLesson)
        XCTAssertEqual(persistedLessons[1], expectedEditedLesson)
    }

    func testBuiltInIDWithDifferentStarterCodeDoesNotReceiveStockDeepContent() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )

        var customizedLesson = stockLesson
        customizedLesson.title = "My incompatible lesson"
        customizedLesson.starterCode = "print(\"I changed the exercise\")"
        customizedLesson.deepContent = nil
        try writeLessons([customizedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])

        XCTAssertEqual(store.lessons, [customizedLesson])
        XCTAssertNil(store.lessons[0].deepContent)
    }

    func testBuiltInIDAndStarterCodeWithDifferentKindDoesNotReceiveStockDeepContent() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )

        var customizedLesson = stockLesson
        customizedLesson.kind = .concept
        customizedLesson.deepContent = nil
        try writeLessons([customizedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])

        XCTAssertEqual(store.lessons, [customizedLesson])
        XCTAssertEqual(try readLessons(), [customizedLesson])
    }

    func testSavedDeepContentIsPreservedInsteadOfReplacingItWithStockContent() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )

        var customizedLesson = stockLesson
        customizedLesson.deepContent = pilotDeepContent(title: "My deep content")
        try writeLessons([customizedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])

        XCTAssertEqual(store.lessons, [customizedLesson])
        XCTAssertEqual(store.lessons[0].deepContent?.title, "My deep content")
        XCTAssertEqual(try readLessons(), [customizedLesson])
    }

    func testOlderBundledRevisionUpgradesToExactCurrentDefaultAndPersists() throws {
        var currentDefault = Curriculum.defaultLessons[0]
        currentDefault.deepContent = pilotDeepContent(
            title: "Current bundled revision",
            provenance: bundledProvenance(revision: 2)
        )
        var savedLesson = currentDefault
        savedLesson.deepContent = pilotDeepContent(
            title: "Older bundled revision",
            provenance: bundledProvenance(revision: 1)
        )
        try writeLessons([savedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [currentDefault])

        XCTAssertEqual(store.lessons[0].deepContent, currentDefault.deepContent)
        XCTAssertEqual(try readLessons()[0].deepContent, currentDefault.deepContent)
    }

    func testEqualBundledRevisionRepairsContentDriftFromCurrentDefault() throws {
        var currentDefault = Curriculum.defaultLessons[0]
        currentDefault.deepContent = pilotDeepContent(
            title: "Canonical bundled content",
            provenance: bundledProvenance(revision: 2)
        )
        var driftedLesson = currentDefault
        driftedLesson.deepContent = pilotDeepContent(
            title: "Drifted content at same revision",
            provenance: bundledProvenance(revision: 2)
        )
        try writeLessons([driftedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [currentDefault])

        XCTAssertEqual(store.lessons[0].deepContent, currentDefault.deepContent)
        XCTAssertEqual(try readLessons()[0].deepContent, currentDefault.deepContent)
    }

    func testCurrentDefaultWithoutBundledContentRemovesSavedBundledContent() throws {
        var currentDefault = Curriculum.defaultLessons[0]
        currentDefault.deepContent = nil
        var savedLesson = currentDefault
        savedLesson.deepContent = pilotDeepContent(
            title: "No longer shipped",
            provenance: bundledProvenance(revision: 1)
        )
        try writeLessons([savedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [currentDefault])

        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertNil(try readLessons()[0].deepContent)
    }

    func testNewerSavedBundledRevisionMakesStoreReadOnlyWithoutDowngradingBytes() throws {
        var currentDefault = Curriculum.defaultLessons[0]
        currentDefault.deepContent = pilotDeepContent(
            title: "Current app content",
            provenance: bundledProvenance(revision: 2)
        )
        var newerSavedLesson = currentDefault
        newerSavedLesson.deepContent = pilotDeepContent(
            title: "Newer saved content",
            provenance: bundledProvenance(revision: 3)
        )
        let secondSavedLesson = Curriculum.defaultLessons[1]
        let missingDefault = Curriculum.defaultLessons[2]
        let originalData = try JSONEncoder().encode([newerSavedLesson, secondSavedLesson])

        try assertReadOnlyStorePreservesEveryByte(
            originalData,
            defaults: [currentDefault, secondSavedLesson, missingDefault]
        )
    }

    func testAddRemovesIncompatibleBundledContentBeforePersisting() throws {
        let currentDefault = Curriculum.defaultLessons[0]
        let store = LessonStore(fileURL: fixtureURL, defaults: [currentDefault])
        var addedLesson = currentDefault
        addedLesson.id = 9_201
        addedLesson.title = "Learner lesson carrying stale bundled content"

        store.add(addedLesson)

        let normalized = try XCTUnwrap(store.lesson(id: addedLesson.id))
        XCTAssertEqual(normalized.title, addedLesson.title)
        XCTAssertNil(normalized.deepContent)
        XCTAssertEqual(try readLessons().last, normalized)
    }

    func testAddPreservesProvenanceNilCustomContent() throws {
        let currentDefault = Curriculum.defaultLessons[0]
        let store = LessonStore(fileURL: fixtureURL, defaults: [currentDefault])
        var addedLesson = currentDefault
        addedLesson.id = 9_202
        addedLesson.deepContent = pilotDeepContent(title: "Learner-authored content")

        store.add(addedLesson)

        XCTAssertEqual(store.lesson(id: addedLesson.id), addedLesson)
        XCTAssertEqual(try readLessons().last, addedLesson)
    }

    func testStarterCodeEditImmediatelyRemovesBundledContentAndKeepsItRemovedAfterReopen() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )
        var savedLesson = stockLesson
        savedLesson.deepContent = nil
        try writeLessons([savedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        XCTAssertEqual(store.lessons[0].deepContent?.provenance, bundledProvenance)

        var draftState = LessonEditorDraftState(draft: store.lessons[0])
        draftState.draft.title = "Keep this learner title"
        draftState.draft.starterCode = "print(\"Learner exercise\")"
        XCTAssertTrue(
            draftState.hasUnsavedChanges(comparedTo: store.lesson(id: draftState.draft.id))
        )

        let normalized = try XCTUnwrap(draftState.commit(to: store))

        XCTAssertEqual(store.lessons[0].title, "Keep this learner title")
        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertEqual(normalized, draftState.draft)
        XCTAssertEqual(normalized, store.lesson(id: draftState.draft.id))
        XCTAssertEqual(normalized, try readLessons()[0])
        XCTAssertFalse(
            draftState.hasUnsavedChanges(comparedTo: store.lesson(id: draftState.draft.id))
        )
        XCTAssertNil(try readLessons()[0].deepContent)

        let reopened = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        XCTAssertEqual(reopened.lesson(id: draftState.draft.id), normalized)
        XCTAssertEqual(reopened.lessons[0].title, "Keep this learner title")
        XCTAssertEqual(reopened.lessons[0].starterCode, "print(\"Learner exercise\")")
        XCTAssertNil(reopened.lessons[0].deepContent)
    }

    func testKindEditImmediatelyRemovesBundledContentAndKeepsItRemovedAfterReopen() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )
        try writeLessons([stockLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        var editedLesson = store.lessons[0]
        editedLesson.kind = .concept
        store.update(editedLesson)

        XCTAssertEqual(store.lessons[0].kind, .concept)
        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertNil(try readLessons()[0].deepContent)

        let reopened = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        XCTAssertEqual(reopened.lessons[0].kind, .concept)
        XCTAssertNil(reopened.lessons[0].deepContent)
    }

    func testCustomProvenanceNilContentSurvivesStarterEditAndReopen() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )
        var customizedLesson = stockLesson
        customizedLesson.deepContent = pilotDeepContent(title: "Learner-authored explanation")
        try writeLessons([customizedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        var editedLesson = store.lessons[0]
        editedLesson.starterCode = "print(\"My custom exercise\")"
        store.update(editedLesson)

        XCTAssertEqual(store.lessons[0].deepContent?.title, "Learner-authored explanation")
        XCTAssertNil(store.lessons[0].deepContent?.provenance)

        let reopened = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])
        XCTAssertEqual(reopened.lessons[0].deepContent?.title, "Learner-authored explanation")
        XCTAssertNil(reopened.lessons[0].deepContent?.provenance)
    }

    func testLoadRemovesPersistedBundledContentWhenStarterNoLongerMatchesDefault() throws {
        var stockLesson = Curriculum.defaultLessons[0]
        stockLesson.deepContent = pilotDeepContent(
            title: "Stock deep content",
            provenance: bundledProvenance
        )
        var staleLesson = stockLesson
        staleLesson.starterCode = "print(\"Changed before this app version\")"
        try writeLessons([staleLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])

        XCTAssertEqual(store.lessons[0].starterCode, staleLesson.starterCode)
        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertNil(try readLessons()[0].deepContent)
    }

    func testLoadRemovesBundledContentWhenNoMatchingDefaultExists() throws {
        var orphanedBundledLesson = Curriculum.defaultLessons[0]
        orphanedBundledLesson.id = 9_101
        try writeLessons([orphanedBundledLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [])

        XCTAssertEqual(store.lessons[0].id, orphanedBundledLesson.id)
        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertNil(try readLessons()[0].deepContent)
    }

    func testUnsupportedNestedDeepContentMakesStoreReadOnlyAndPreservesEveryByte() throws {
        let unsupportedLesson = Curriculum.defaultLessons[0]
        let secondSavedLesson = Curriculum.defaultLessons[1]
        let missingDefault = Curriculum.defaultLessons[2]
        let originalData = try encodedLessonsWithFutureMicroscopeRequirement(
            [unsupportedLesson, secondSavedLesson]
        )
        try originalData.write(to: fixtureURL, options: .atomic)

        let store = LessonStore(
            fileURL: fixtureURL,
            defaults: [unsupportedLesson, secondSavedLesson, missingDefault]
        )
        let safelyDecodedLessons = store.lessons

        XCTAssertTrue(store.isReadOnlyForUnsupportedDeepContent)
        XCTAssertEqual(store.lessons.map(\.id), [unsupportedLesson.id, secondSavedLesson.id])
        XCTAssertTrue(store.lessons[0].hasUnsupportedDeepContent)
        XCTAssertNil(store.lessons[0].deepContent)
        XCTAssertFalse(store.lessons[1].hasUnsupportedDeepContent)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)

        var addedLesson = missingDefault
        addedLesson.id = 9_001
        store.add(addedLesson)
        XCTAssertEqual(store.lessons, safelyDecodedLessons)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)

        var updatedLesson = store.lessons[1]
        updatedLesson.title = "This update must not be applied"
        XCTAssertNil(store.update(updatedLesson))
        XCTAssertEqual(store.lessons, safelyDecodedLessons)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)

        store.delete(id: secondSavedLesson.id)
        XCTAssertEqual(store.lessons, safelyDecodedLessons)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)

        store.move(id: unsupportedLesson.id, by: 1)
        XCTAssertEqual(store.lessons, safelyDecodedLessons)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)

        store.restoreDefaults()
        XCTAssertEqual(store.lessons, safelyDecodedLessons)
        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)
    }

    func testFutureDeepContentSchemaMakesStoreGloballyReadOnlyAndPreservesEveryByte() throws {
        let firstSavedLesson = Curriculum.defaultLessons[0]
        let secondSavedLesson = Curriculum.defaultLessons[1]
        let missingDefault = Curriculum.defaultLessons[2]
        let originalData = try encodedLessonsWithFutureDeepContentSchema(
            [firstSavedLesson, secondSavedLesson]
        )

        try assertReadOnlyStorePreservesEveryByte(
            originalData,
            defaults: [firstSavedLesson, secondSavedLesson, missingDefault]
        )
    }

    func testNewerBundledRevisionWithIncompatibleStarterIsReadOnlyBeforeReconciliation() throws {
        let currentDefault = Curriculum.defaultLessons[0]
        var futureRevisionLesson = currentDefault
        futureRevisionLesson.starterCode = "print(\"Future custom starter\")"
        futureRevisionLesson.deepContent = pilotDeepContent(
            title: "Future bundled revision",
            provenance: bundledProvenance(revision: 2)
        )
        let secondSavedLesson = Curriculum.defaultLessons[1]
        let missingDefault = Curriculum.defaultLessons[2]
        let originalData = try JSONEncoder().encode(
            [futureRevisionLesson, secondSavedLesson]
        )

        try assertReadOnlyStorePreservesEveryByte(
            originalData,
            defaults: [currentDefault, secondSavedLesson, missingDefault]
        )
    }

    func testNewerBundledRevisionWithoutMatchingDefaultIsReadOnlyBeforeRemoval() throws {
        var futureRevisionLesson = Curriculum.defaultLessons[0]
        futureRevisionLesson.id = 9_301
        futureRevisionLesson.deepContent = pilotDeepContent(
            title: "Future orphaned bundled revision",
            provenance: bundledProvenance(revision: 2)
        )
        let secondSavedLesson = Curriculum.defaultLessons[1]
        let missingDefault = Curriculum.defaultLessons[2]
        let originalData = try JSONEncoder().encode(
            [futureRevisionLesson, secondSavedLesson]
        )

        try assertReadOnlyStorePreservesEveryByte(
            originalData,
            defaults: [secondSavedLesson, missingDefault]
        )
    }

    func testMissingDefaultIsAppendedOnceAndExistingOrderIsPreservedAcrossReopen() throws {
        let firstStockLesson = Curriculum.defaultLessons[0]
        let missingStockLesson = Curriculum.defaultLessons[1]
        var customLesson = Curriculum.defaultLessons[2]
        customLesson.id = 9_001
        customLesson.title = "My custom lesson"
        customLesson.deepContent = nil
        try writeLessons([customLesson, firstStockLesson])

        let defaults = [firstStockLesson, missingStockLesson]
        let firstStore = LessonStore(fileURL: fixtureURL, defaults: defaults)
        XCTAssertEqual(
            firstStore.lessons.map(\.id),
            [customLesson.id, firstStockLesson.id, missingStockLesson.id]
        )
        XCTAssertEqual(
            try readLessons(),
            [customLesson, firstStockLesson, missingStockLesson]
        )

        let reopenedStore = LessonStore(fileURL: fixtureURL, defaults: defaults)
        XCTAssertEqual(
            reopenedStore.lessons.map(\.id),
            [customLesson.id, firstStockLesson.id, missingStockLesson.id]
        )
        XCTAssertEqual(
            reopenedStore.lessons.filter { $0.id == missingStockLesson.id }.count,
            1
        )
    }

    func testRestoreDefaultsUsesInjectedDefaults() throws {
        var injectedDefault = Curriculum.defaultLessons[0]
        injectedDefault.id = 8_001
        injectedDefault.title = "Injected default"
        var savedLesson = Curriculum.defaultLessons[1]
        savedLesson.id = 8_002
        try writeLessons([savedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [injectedDefault])
        store.restoreDefaults()

        XCTAssertEqual(store.lessons, [injectedDefault])
        XCTAssertEqual(try readLessons(), [injectedDefault])
    }

    func testCompatibleSavedFileWithoutMergeChangesIsNotRewritten() throws {
        let savedLessons = [Curriculum.defaultLessons[0]]
        try writeLessons(savedLessons)
        let originalData = try Data(contentsOf: fixtureURL)

        _ = LessonStore(fileURL: fixtureURL, defaults: savedLessons)

        XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)
    }

    func testCurriculumStillContainsExactlyTwentyFourUniqueLessonIDs() {
        let ids = Curriculum.defaultLessons.map(\.id)

        XCTAssertEqual(ids.count, 24)
        XCTAssertEqual(Set(ids).count, 24)
    }

    func testUpdateReturnsNilForMissingLessonID() {
        let store = LessonStore(
            fileURL: fixtureURL,
            defaults: [Curriculum.defaultLessons[0]]
        )
        var missingLesson = Curriculum.defaultLessons[0]
        missingLesson.id = 9_999

        XCTAssertNil(store.update(missingLesson))
    }

    private func writeLessons(_ lessons: [Lesson]) throws {
        let data = try JSONEncoder().encode(lessons)
        try data.write(to: fixtureURL, options: .atomic)
    }

    private func readLessons() throws -> [Lesson] {
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode([Lesson].self, from: data)
    }

    private var bundledProvenance: LessonDeepContentProvenance {
        bundledProvenance(revision: 1)
    }

    private func bundledProvenance(revision: Int) -> LessonDeepContentProvenance {
        LessonDeepContentProvenance(source: .bundled, revision: revision)
    }

    private func encodedLessonsWithFutureMicroscopeRequirement(
        _ lessons: [Lesson]
    ) throws -> Data {
        let encoded = try JSONEncoder().encode(lessons)
        var array = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [[String: Any]]
        )
        var deepContent = try XCTUnwrap(array[0]["deepContent"] as? [String: Any])
        var tokens = try XCTUnwrap(deepContent["microscopeTokens"] as? [[String: Any]])
        tokens[0]["requirement"] = "introduced-by-a-future-app"
        deepContent["microscopeTokens"] = tokens
        array[0]["deepContent"] = deepContent
        return try JSONSerialization.data(
            withJSONObject: array,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func encodedLessonsWithFutureDeepContentSchema(
        _ lessons: [Lesson]
    ) throws -> Data {
        let encoded = try JSONEncoder().encode(lessons)
        var array = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [[String: Any]]
        )
        var deepContent = try XCTUnwrap(array[0]["deepContent"] as? [String: Any])
        deepContent["schemaVersion"] = 2
        deepContent["futureInteractiveLab"] = ["steps": ["new step"]]
        array[0]["deepContent"] = deepContent
        return try JSONSerialization.data(
            withJSONObject: array,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    private func assertReadOnlyStorePreservesEveryByte(
        _ originalData: Data,
        defaults: [Lesson]
    ) throws {
        try originalData.write(to: fixtureURL, options: .atomic)
        let store = LessonStore(fileURL: fixtureURL, defaults: defaults)
        let safelyDecodedLessons = store.lessons
        XCTAssertGreaterThanOrEqual(safelyDecodedLessons.count, 2)

        func assertUnchanged() throws {
            XCTAssertEqual(store.lessons, safelyDecodedLessons)
            XCTAssertEqual(try Data(contentsOf: fixtureURL), originalData)
        }

        XCTAssertTrue(store.isReadOnlyForUnsupportedDeepContent)
        try assertUnchanged()

        var addedLesson = try XCTUnwrap(defaults.last)
        addedLesson.id = 99_901
        store.add(addedLesson)
        try assertUnchanged()

        var updatedLesson = safelyDecodedLessons[1]
        updatedLesson.title = "This update must stay blocked"
        XCTAssertNil(store.update(updatedLesson))
        try assertUnchanged()

        store.delete(id: safelyDecodedLessons[1].id)
        try assertUnchanged()

        store.move(id: safelyDecodedLessons[0].id, by: 1)
        try assertUnchanged()

        store.restoreDefaults()
        try assertUnchanged()
    }

    private func pilotDeepContent(
        title: String,
        provenance: LessonDeepContentProvenance? = nil
    ) -> LessonDeepContent {
        LessonDeepContent(
            title: title,
            introduction: "A synthetic migration fixture.",
            segments: [
                DeepLessonSegment(
                    id: "segment",
                    title: "A segment",
                    explanation: "A focused explanation.",
                    correctCode: "print(\"Hello\")",
                    wrongCode: nil,
                    wrongExplanation: nil
                )
            ],
            microscopeTokens: [],
            modifyTask: ModifyTask(
                id: "modify",
                prompt: "Change the message.",
                starterCode: "print(\"Hello\")",
                expectedCode: "print(\"Hi\")",
                predictionPrompt: "What prints?",
                expectedOutput: "Hi",
                successExplanation: "The changed string is printed.",
                conceptIDs: ["segment"]
            ),
            recallQuestions: [],
            provenance: provenance
        )
    }
}
