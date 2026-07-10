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
        XCTAssertFalse(lesson.hasUnsupportedDeepContent)
    }

    func testCustomLessonIDWithoutNewFieldsStillDecodes() throws {
        let data = try lessonData(id: 9_001)
        let lesson = try XCTUnwrap(JSONDecoder().decode([Lesson].self, from: data).first)

        XCTAssertEqual(lesson.id, 9_001)
        XCTAssertEqual(lesson.kind, .code)
        XCTAssertNil(lesson.deepContent)
        XCTAssertFalse(lesson.hasUnsupportedDeepContent)
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
        XCTAssertTrue(lesson.hasUnsupportedDeepContent)
    }

    func testNullDeepContentIsMissingRatherThanUnsupported() throws {
        var lesson = lessonJSONObject(id: 43)
        lesson["deepContent"] = NSNull()
        let data = try JSONSerialization.data(withJSONObject: lesson)

        let decoded = try JSONDecoder().decode(Lesson.self, from: data)

        XCTAssertNil(decoded.deepContent)
        XCTAssertFalse(decoded.hasUnsupportedDeepContent)
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

    func testLegacyDeepContentWithoutProvenanceRemainsValidCustomContentOnRoundTrip() throws {
        let data = Data(
            #"""
            {
              "id": 74,
              "title": "Legacy deep lesson",
              "goal": "Preserve authored content",
              "starterCode": "print(\"Legacy\")",
              "teaches": ["print"],
              "glossaryTerms": ["String"],
              "syntaxTokens": [],
              "syntaxWhy": "Legacy syntax explanation",
              "expectedOutput": "Legacy",
              "successMarkers": ["print("],
              "successMessage": "Legacy success",
              "hint": "Legacy hint",
              "deepContent": {
                "title": "Legacy authored explanation",
                "introduction": "This predates provenance.",
                "segments": [{
                  "id": "legacy-segment",
                  "title": "Legacy segment",
                  "explanation": "Explain the legacy call.",
                  "correctCode": "print(\"Legacy\")",
                  "wrongCode": null,
                  "wrongExplanation": null
                }],
                "microscopeTokens": [{
                  "id": "legacy-token",
                  "display": "print",
                  "role": "Call a function",
                  "requirement": "required",
                  "explanation": "The function writes output.",
                  "ifChanged": "A different name changes the call."
                }],
                "modifyTask": {
                  "id": "legacy-modify",
                  "prompt": "Change the message.",
                  "starterCode": "print(\"Legacy\")",
                  "expectedCode": "print(\"Custom\")",
                  "predictionPrompt": "What prints?",
                  "expectedOutput": "Custom",
                  "successExplanation": "The custom text prints.",
                  "conceptIDs": ["legacy-print"]
                },
                "recallQuestions": [{
                  "id": "legacy-recall",
                  "prompt": "What writes output?",
                  "choices": ["print", "let"],
                  "correctChoiceIndex": 0,
                  "explanation": "print writes output.",
                  "conceptIDs": ["legacy-print"]
                }]
              }
            }
            """#.utf8
        )

        let decoded = try JSONDecoder().decode(Lesson.self, from: data)
        let content = try XCTUnwrap(decoded.deepContent)

        XCTAssertFalse(decoded.hasUnsupportedDeepContent)
        XCTAssertNil(content.provenance)
        XCTAssertEqual(content.schemaVersion, 1)
        XCTAssertEqual(content.title, "Legacy authored explanation")

        let encoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(Lesson.self, from: encoded)
        XCTAssertEqual(roundTripped.deepContent, content)
        XCTAssertFalse(roundTripped.hasUnsupportedDeepContent)
        XCTAssertNil(roundTripped.deepContent?.provenance)
        XCTAssertEqual(roundTripped.deepContent?.schemaVersion, 1)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let deepContent = try XCTUnwrap(object["deepContent"] as? [String: Any])
        XCTAssertNil(deepContent["provenance"])
        XCTAssertEqual(deepContent["schemaVersion"] as? Int, 1)
    }

    func testFutureDeepContentSchemaWithAdditiveKeyIsUnsupported() throws {
        let data = try lessonDataWithDeepContentSchemaVersion(
            2,
            additiveKey: ("futureInteractiveLab", ["steps": ["new step"]])
        )

        let decoded = try JSONDecoder().decode(Lesson.self, from: data)

        XCTAssertNil(decoded.deepContent)
        XCTAssertTrue(decoded.hasUnsupportedDeepContent)
    }

    func testMalformedDeepContentSchemaVersionIsUnsupported() throws {
        let data = try lessonDataWithDeepContentSchemaVersion("version two")

        let decoded = try JSONDecoder().decode(Lesson.self, from: data)

        XCTAssertNil(decoded.deepContent)
        XCTAssertTrue(decoded.hasUnsupportedDeepContent)
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
            ],
            provenance: LessonDeepContentProvenance(source: .bundled, revision: 1)
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
        XCTAssertEqual(decoded.deepContent?.schemaVersion, 1)
        XCTAssertEqual(
            decoded.deepContent?.provenance,
            LessonDeepContentProvenance(source: .bundled, revision: 1)
        )
        XCTAssertFalse(decoded.hasUnsupportedDeepContent)

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        XCTAssertNil(object["hasUnsupportedDeepContent"])
        let encodedDeepContent = try XCTUnwrap(object["deepContent"] as? [String: Any])
        XCTAssertEqual(encodedDeepContent["schemaVersion"] as? Int, 1)
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

    private func lessonDataWithDeepContentSchemaVersion(
        _ schemaVersion: Any,
        additiveKey: (String, Any)? = nil
    ) throws -> Data {
        let encoded = try JSONEncoder().encode(Curriculum.defaultLessons[0])
        var lesson = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        var deepContent = try XCTUnwrap(lesson["deepContent"] as? [String: Any])
        deepContent["schemaVersion"] = schemaVersion
        if let additiveKey {
            deepContent[additiveKey.0] = additiveKey.1
        }
        lesson["deepContent"] = deepContent
        return try JSONSerialization.data(
            withJSONObject: lesson,
            options: [.prettyPrinted, .sortedKeys]
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
