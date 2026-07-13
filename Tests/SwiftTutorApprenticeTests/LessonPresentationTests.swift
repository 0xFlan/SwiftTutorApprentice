import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class LessonPresentationTests: XCTestCase {
    func testPresentationRoundTripPreservesAuthoredContent() throws {
        let presentation = makePresentation()

        let encoded = try JSONEncoder().encode(presentation)
        let decoded = try JSONDecoder().decode(LessonPresentation.self, from: encoded)

        XCTAssertEqual(decoded, presentation)
        XCTAssertEqual(decoded.id, "swift.lesson-1.presentation")
        XCTAssertEqual(decoded.posterState.description, "The print call before it runs.")
        XCTAssertEqual(decoded.scenes.first?.id, "execute-print")
        XCTAssertEqual(decoded.scenes.first?.before.values.first?.value, "Hello")
        XCTAssertEqual(decoded.scenes.first?.after.output, "Hello")
        XCTAssertEqual(decoded.scenes.first?.focusTargets.first?.kind, .codeToken)
        XCTAssertEqual(decoded.transcript, "Swift evaluates the string, then print sends it to output.")
        XCTAssertEqual(decoded.conceptIDs, ["swift.print", "swift.string-literal"])
        XCTAssertEqual(decoded.objectiveMappings.first?.objectiveID.rawValue, "3.1")
        XCTAssertEqual(decoded.provenance, .init(source: .bundled, revision: 4))
        XCTAssertEqual(decoded.aiCodeExercise?.claims.map(\.id), ["claim-correct", "claim-wrong"])
        XCTAssertEqual(decoded.aiCodeExercise?.claims.map(\.isCorrect), [true, false])
    }

    func testEncoderAlwaysWritesCurrentSchemaVersion() throws {
        let encoded = try JSONEncoder().encode(makePresentation(schemaVersion: 999))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
    }

    func testDecoderRejectsFutureSchemaVersion() throws {
        let encoded = try JSONEncoder().encode(makePresentation())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object["schemaVersion"] = 2
        let futureData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(
            try JSONDecoder().decode(LessonPresentation.self, from: futureData)
        ) { error in
            guard case DecodingError.dataCorrupted = error else {
                XCTFail("Expected DecodingError.dataCorrupted, got \(error)")
                return
            }
        }
    }

    private func makePresentation(schemaVersion: Int = 1) -> LessonPresentation {
        let before = PresentationVisualState(
            code: "print(\"Hello\")",
            codeTokens: [
                PresentationCodeToken(id: "print-token", text: "print")
            ],
            values: [
                PresentationValue(id: "message-value", name: "message", value: "Hello")
            ],
            output: nil,
            outputTargetID: "console",
            description: "The print call before it runs."
        )
        let after = PresentationVisualState(
            code: "print(\"Hello\")",
            codeTokens: [
                PresentationCodeToken(id: "print-token", text: "print")
            ],
            values: [
                PresentationValue(id: "message-value", name: "message", value: "Hello")
            ],
            output: "Hello",
            outputTargetID: "console",
            description: "The string has reached the console."
        )
        let mapping = ObjectiveMapping(
            conceptID: "swift.print",
            objectiveSetID: ObjectiveSetID(rawValue: "swift-associate-2024"),
            objectiveID: ObjectiveID(rawValue: "3.1")
        )

        return LessonPresentation(
            schemaVersion: schemaVersion,
            id: "swift.lesson-1.presentation",
            title: "Watch print execute",
            posterDescription: "Follow a value from source code to output.",
            posterState: before,
            scenes: [
                PresentationScene(
                    id: "execute-print",
                    title: "Run the call",
                    caption: "print receives one String value.",
                    narration: "Swift evaluates the string before print writes it.",
                    staticDescription: "An arrow connects the string value to the console.",
                    visualKind: .outputFlow,
                    focusTargets: [
                        PresentationFocusTarget(kind: .codeToken, id: "print-token"),
                        PresentationFocusTarget(kind: .value, id: "message-value"),
                        PresentationFocusTarget(kind: .output, id: "console")
                    ],
                    before: before,
                    after: after
                )
            ],
            transcript: "Swift evaluates the string, then print sends it to output.",
            narrationLocale: "en-US",
            finalRecallQuestionID: "recall-print-output",
            aiCodeExercise: AICodeReviewExercise(
                id: "review-generated-print",
                prompt: "Review this generated print call.",
                generatedCode: "print(\"Hello\")",
                claims: [
                    AICodeClaim(
                        id: "claim-correct",
                        text: "The code prints Hello.",
                        isCorrect: true,
                        explanation: "The String is the argument passed to print."
                    ),
                    AICodeClaim(
                        id: "claim-wrong",
                        text: "The quotes appear in the output.",
                        isCorrect: false,
                        explanation: "Quotes delimit a String literal; they are not printed."
                    )
                ],
                conceptIDs: ["swift.print", "swift.string-literal"]
            ),
            conceptIDs: ["swift.print", "swift.string-literal"],
            objectiveMappings: [mapping],
            provenance: LessonPresentationProvenance(source: .bundled, revision: 4)
        )
    }
}
