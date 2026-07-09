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
        stockLesson.deepContent = pilotDeepContent(title: "Stock deep content")
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
        stockLesson.deepContent = pilotDeepContent(title: "Stock deep content")

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
        stockLesson.deepContent = pilotDeepContent(title: "Stock deep content")

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
        stockLesson.deepContent = pilotDeepContent(title: "Stock deep content")

        var customizedLesson = stockLesson
        customizedLesson.deepContent = pilotDeepContent(title: "My deep content")
        try writeLessons([customizedLesson])

        let store = LessonStore(fileURL: fixtureURL, defaults: [stockLesson])

        XCTAssertEqual(store.lessons, [customizedLesson])
        XCTAssertEqual(store.lessons[0].deepContent?.title, "My deep content")
        XCTAssertEqual(try readLessons(), [customizedLesson])
    }

    func testMissingDefaultIsAppendedOnceAndExistingOrderIsPreservedAcrossReopen() throws {
        let firstStockLesson = Curriculum.defaultLessons[0]
        let missingStockLesson = Curriculum.defaultLessons[1]
        var customLesson = Curriculum.defaultLessons[2]
        customLesson.id = 9_001
        customLesson.title = "My custom lesson"
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

    private func writeLessons(_ lessons: [Lesson]) throws {
        let data = try JSONEncoder().encode(lessons)
        try data.write(to: fixtureURL, options: .atomic)
    }

    private func readLessons() throws -> [Lesson] {
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode([Lesson].self, from: data)
    }

    private func pilotDeepContent(title: String) -> LessonDeepContent {
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
            recallQuestions: []
        )
    }
}
