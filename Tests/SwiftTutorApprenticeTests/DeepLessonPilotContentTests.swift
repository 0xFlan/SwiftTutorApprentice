import XCTest
@testable import SwiftTutorApprentice

final class DeepLessonPilotContentTests: XCTestCase {
    func testDefaultCurriculumKeepsExactlyTwentyFourOrderedUniqueLessons() {
        let ids = Curriculum.defaultLessons.map(\.id)

        XCTAssertEqual(Curriculum.defaultLessons.count, 24)
        XCTAssertEqual(ids, Array(1...24))
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testOnlyFirstThreeLessonsHaveDeepContent() {
        for lessonID in 1...3 {
            XCTAssertNotNil(
                Curriculum.defaultLesson(id: lessonID)?.deepContent,
                "Lesson \(lessonID) should have pilot deep content"
            )
        }

        for lessonID in 4...24 {
            XCTAssertNil(
                Curriculum.defaultLesson(id: lessonID)?.deepContent,
                "Lesson \(lessonID) should keep the existing lesson flow"
            )
        }
    }

    func testEveryPilotLessonMeetsTheCompleteContentContract() throws {
        for lessonID in 1...3 {
            let content = try pilotContent(lessonID: lessonID)
            let namespace = "lesson-\(lessonID)-"

            assertNotBlank(content.title, "Lesson \(lessonID) title")
            assertNotBlank(content.introduction, "Lesson \(lessonID) introduction")
            XCTAssertGreaterThanOrEqual(content.segments.count, 1)
            XCTAssertGreaterThanOrEqual(content.microscopeTokens.count, 1)
            XCTAssertGreaterThanOrEqual(content.recallQuestions.count, 1)

            for segment in content.segments {
                assertNamespaced(segment.id, namespace: namespace)
                assertNotBlank(segment.title, "Segment \(segment.id) title")
                assertNotBlank(segment.explanation, "Segment \(segment.id) explanation")
                assertNotBlank(segment.correctCode, "Segment \(segment.id) correct code")
                assertNotBlank(segment.wrongCode, "Segment \(segment.id) wrong code")
                assertNotBlank(segment.wrongExplanation, "Segment \(segment.id) wrong explanation")
            }

            for token in content.microscopeTokens {
                assertNamespaced(token.id, namespace: namespace)
                assertNotBlank(token.display, "Token \(token.id) display")
                assertNotBlank(token.role, "Token \(token.id) role")
                assertNotBlank(token.explanation, "Token \(token.id) explanation")
                assertNotBlank(token.ifChanged, "Token \(token.id) if-changed explanation")
            }
            XCTAssertTrue(content.microscopeTokens.contains { $0.requirement == .required })
            XCTAssertTrue(content.microscopeTokens.contains { $0.requirement == .convention })

            let modifyTask = content.modifyTask
            assertNamespaced(modifyTask.id, namespace: namespace)
            assertNotBlank(modifyTask.prompt, "Modify prompt")
            assertNotBlank(modifyTask.starterCode, "Modify starter code")
            assertNotBlank(modifyTask.expectedCode, "Modify expected code")
            assertNotBlank(modifyTask.predictionPrompt, "Modify prediction prompt")
            assertNotBlank(modifyTask.expectedOutput, "Modify expected output")
            assertNotBlank(modifyTask.successExplanation, "Modify success explanation")
            XCTAssertFalse(modifyTask.conceptIDs.isEmpty)
            modifyTask.conceptIDs.forEach {
                assertNotBlank($0.rawValue, "Modify concept ID")
            }

            for question in content.recallQuestions {
                assertNamespaced(question.id, namespace: namespace)
                assertNotBlank(question.prompt, "Recall \(question.id) prompt")
                XCTAssertGreaterThanOrEqual(question.choices.count, 2)
                question.choices.forEach {
                    assertNotBlank($0, "Recall \(question.id) choice")
                }
                XCTAssertTrue(question.choices.indices.contains(question.correctChoiceIndex))
                assertNotBlank(question.explanation, "Recall \(question.id) explanation")
                XCTAssertFalse(question.conceptIDs.isEmpty)
                question.conceptIDs.forEach {
                    assertNotBlank($0.rawValue, "Recall \(question.id) concept ID")
                }
            }

            assertUnique(content.segments.map(\.id), category: "segment", lessonID: lessonID)
            assertUnique(content.microscopeTokens.map(\.id), category: "token", lessonID: lessonID)
            assertUnique(content.recallQuestions.map(\.id), category: "recall question", lessonID: lessonID)
        }
    }

    func testLessonOneIncludesBothNamedMisconceptions() throws {
        let content = try pilotContent(lessonID: 1)
        let missingQuotes = try segment("lesson-1-missing-quotes", in: content)
        let differentLiteral = try segment("lesson-1-different-literal", in: content)

        XCTAssertEqual(missingQuotes.correctCode, "print(\"Hello, Swift!\")")
        XCTAssertEqual(missingQuotes.wrongCode, "print(Hello, Swift!)")
        XCTAssertTrue(missingQuotes.wrongExplanation?.lowercased().contains("quotation") == true)

        XCTAssertEqual(differentLiteral.correctCode, "print(\"Hello, Swift!\")")
        XCTAssertEqual(differentLiteral.wrongCode, "print(\"Goodbye, Swift!\")")
        XCTAssertTrue(differentLiteral.wrongExplanation?.lowercased().contains("output") == true)
    }

    func testLessonTwoIncludesBothNamedMisconceptions() throws {
        let content = try pilotContent(lessonID: 2)
        let quotedName = try segment("lesson-2-quoted-name", in: content)
        let reassignment = try segment("lesson-2-let-reassignment", in: content)

        XCTAssertTrue(quotedName.correctCode?.contains("print(name)") == true)
        XCTAssertTrue(quotedName.wrongCode?.contains("print(\"name\")") == true)
        XCTAssertTrue(quotedName.wrongExplanation?.lowercased().contains("literal") == true)

        XCTAssertTrue(reassignment.wrongCode?.contains("let name = \"Alex\"\nname = \"Sam\"") == true)
        XCTAssertTrue(reassignment.wrongExplanation?.lowercased().contains("cannot") == true)
    }

    func testLessonThreeIncludesNamedLetReassignmentMisconception() throws {
        let content = try pilotContent(lessonID: 3)
        let reassignment = try segment("lesson-3-let-reassignment", in: content)

        XCTAssertTrue(reassignment.correctCode?.contains("var count = 1\ncount = 2") == true)
        XCTAssertTrue(reassignment.wrongCode?.contains("let count = 1\ncount = 2") == true)
        XCTAssertTrue(reassignment.wrongExplanation?.lowercased().contains("compile") == true)
    }

    func testModifyTasksMatchThePilotExercisesExactly() throws {
        let lesson1Task = try pilotContent(lessonID: 1).modifyTask
        XCTAssertEqual(lesson1Task.starterCode, "print(\"Hello, Swift!\")")
        XCTAssertEqual(lesson1Task.expectedCode, "print(\"Hello, learner!\")")
        XCTAssertEqual(lesson1Task.expectedOutput, "Hello, learner!")

        let lesson2Task = try pilotContent(lessonID: 2).modifyTask
        XCTAssertEqual(lesson2Task.starterCode, "let name = \"Alex\"\nprint(name)")
        XCTAssertEqual(lesson2Task.expectedCode, "let name = \"Sam\"\nprint(name)")
        XCTAssertEqual(lesson2Task.expectedOutput, "Sam")

        let lesson3Task = try pilotContent(lessonID: 3).modifyTask
        XCTAssertEqual(lesson3Task.starterCode, "var count = 1\ncount = 2\nprint(count)")
        XCTAssertEqual(lesson3Task.expectedCode, "var count = 1\ncount = 5\nprint(count)")
        XCTAssertEqual(lesson3Task.expectedOutput, "5")
    }

    private func pilotContent(lessonID: Int) throws -> LessonDeepContent {
        let lesson = try XCTUnwrap(Curriculum.defaultLesson(id: lessonID))
        return try XCTUnwrap(
            lesson.deepContent,
            "Lesson \(lessonID) should have pilot deep content"
        )
    }

    private func segment(
        _ id: String,
        in content: LessonDeepContent
    ) throws -> DeepLessonSegment {
        try XCTUnwrap(content.segments.first { $0.id == id }, "Missing segment \(id)")
    }

    private func assertNamespaced(
        _ id: String,
        namespace: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertNotBlank(id, "ID", file: file, line: line)
        XCTAssertTrue(id.hasPrefix(namespace), "\(id) should start with \(namespace)", file: file, line: line)
    }

    private func assertUnique(
        _ ids: [String],
        category: String,
        lessonID: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            Set(ids).count,
            ids.count,
            "Lesson \(lessonID) \(category) IDs should be unique",
            file: file,
            line: line
        )
    }

    private func assertNotBlank(
        _ value: String?,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(value, "\(label) should not be nil", file: file, line: line)
        XCTAssertFalse(
            value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
            "\(label) should not be empty",
            file: file,
            line: line
        )
    }
}
