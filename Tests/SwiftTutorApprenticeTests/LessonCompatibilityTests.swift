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

    func testDeepLessonContentRoundTrips() throws {
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

        let encoded = try JSONEncoder().encode(content)
        let decoded = try JSONDecoder().decode(LessonDeepContent.self, from: encoded)

        XCTAssertEqual(decoded, content)
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
        return try JSONSerialization.data(withJSONObject: [lesson])
    }
}
