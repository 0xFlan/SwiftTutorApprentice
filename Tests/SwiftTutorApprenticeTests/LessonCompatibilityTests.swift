import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class LessonCompatibilityTests: XCTestCase {
    func testLegacyLessonWithoutKindOrDeepContentPreservesEveryField() throws {
        let lessons = try JSONDecoder().decode([Lesson].self, from: legacyLessonsFixtureData())
        let lesson = try XCTUnwrap(lessons.first)

        XCTAssertEqual(lessons.count, 1)
        XCTAssertEqual(lesson.id, 1)
        XCTAssertEqual(lesson.title, "My preserved Printing title")
        XCTAssertEqual(lesson.goal, "My preserved goal")
        XCTAssertEqual(lesson.starterCode, "print(\"Hello, Swift!\")")
        XCTAssertEqual(lesson.teaches, ["print"])
        XCTAssertEqual(lesson.glossaryTerms, ["String"])
        XCTAssertEqual(lesson.syntaxTokens, [])
        XCTAssertEqual(lesson.syntaxWhy, "My preserved syntax note")
        XCTAssertEqual(lesson.expectedOutput, "Hello, Swift!")
        XCTAssertEqual(lesson.successMarkers, ["print("])
        XCTAssertEqual(lesson.successMessage, "My preserved success message")
        XCTAssertEqual(lesson.hint, "My preserved hint")
        XCTAssertEqual(lesson.kind, .code)
        XCTAssertNil(lesson.deepContent)
    }

    func testCustomLessonIDWithoutNewFieldsStillDecodes() throws {
        let data = try lessonData(id: 9_001)
        let lesson = try XCTUnwrap(JSONDecoder().decode([Lesson].self, from: data).first)

        XCTAssertEqual(lesson.id, 9_001)
        XCTAssertEqual(lesson.kind, .code)
        XCTAssertNil(lesson.deepContent)
    }

    func testMalformedDeepContentFallsBackToNil() throws {
        let malformedDeepContent: [String: Any] = [
            "title": 42,
            "segments": "not an array"
        ]
        let data = try lessonData(id: 41, deepContent: malformedDeepContent)

        let lesson = try XCTUnwrap(JSONDecoder().decode([Lesson].self, from: data).first)

        XCTAssertEqual(lesson.id, 41)
        XCTAssertNil(lesson.deepContent)
    }

    func testMalformedRequiredLegacyFieldStillThrowsDecodingError() throws {
        var malformedLesson = lessonJSONObject(id: 42)
        malformedLesson["id"] = "not an integer"
        let data = try JSONSerialization.data(withJSONObject: malformedLesson)

        XCTAssertThrowsError(try JSONDecoder().decode(Lesson.self, from: data)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected DecodingError.typeMismatch, got \(error)")
                return
            }
        }
    }

    func testLessonWithDeepContentRoundTrips() throws {
        let content = LessonDeepContent(
            title: "Printing in detail",
            introduction: "Learn what every part of a print call does.",
            segments: [
                DeepLessonSegment(
                    id: "print-call",
                    title: "Call print",
                    explanation: "Pass a value to the print function.",
                    correctCode: "print(\"Hello\")",
                    wrongCode: "print \"Hello\"",
                    wrongExplanation: "A function call needs parentheses."
                )
            ],
            microscopeTokens: [
                SyntaxMicroscopeToken(
                    id: "open-paren",
                    display: "(",
                    role: "Starts the argument list",
                    requirement: .required,
                    explanation: "Swift uses parentheses for a function call.",
                    ifChanged: "Removing it makes the call invalid."
                )
            ],
            modifyTask: ModifyTask(
                id: "change-message",
                prompt: "Change the printed message.",
                starterCode: "print(\"Hello\")",
                expectedCode: "print(\"Hello, Swift!\")",
                predictionPrompt: "What will appear in the console?",
                expectedOutput: "Hello, Swift!",
                successExplanation: "The string inside print becomes the output.",
                conceptIDs: ["print-call"]
            ),
            recallQuestions: [
                RecallQuestion(
                    id: "required-parentheses",
                    prompt: "Which characters are required for this call?",
                    choices: ["Parentheses", "A semicolon"],
                    correctChoiceIndex: 0,
                    explanation: "The parentheses contain print's arguments.",
                    conceptIDs: ["print-call"]
                )
            ]
        )
        let lesson = Lesson(
            id: 73,
            title: "Deep printing",
            goal: "Understand a print call",
            starterCode: "print(\"Hello\")",
            teaches: ["print", "String literals"],
            glossaryTerms: ["String"],
            syntaxTokens: [],
            syntaxWhy: "Parentheses contain the function input.",
            expectedOutput: "Hello",
            successMarkers: ["print(", "Hello"],
            successMessage: "The print call is complete.",
            hint: "Keep the text inside parentheses.",
            kind: .code,
            deepContent: content
        )

        let encoded = try JSONEncoder().encode(lesson)
        let decoded = try JSONDecoder().decode(Lesson.self, from: encoded)

        XCTAssertEqual(decoded, lesson)
        XCTAssertEqual(decoded.deepContent, content)
    }

    private func legacyLessonsFixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "legacy-lessons",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        return try Data(contentsOf: url)
    }

    private func lessonData(id: Int, deepContent: Any? = nil) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: [lessonJSONObject(id: id, deepContent: deepContent)]
        )
    }

    private func lessonJSONObject(id: Int, deepContent: Any? = nil) -> [String: Any] {
        var lesson: [String: Any] = [
            "id": id,
            "title": "Legacy custom lesson",
            "goal": "Keep decoding",
            "starterCode": "print(\"Legacy\")",
            "teaches": ["print"],
            "glossaryTerms": ["String"],
            "syntaxTokens": [],
            "syntaxWhy": "Legacy syntax note",
            "expectedOutput": "Legacy",
            "successMarkers": ["print("],
            "successMessage": "Legacy success message",
            "hint": "Legacy hint"
        ]
        if let deepContent {
            lesson["deepContent"] = deepContent
        }
        return lesson
    }
}
