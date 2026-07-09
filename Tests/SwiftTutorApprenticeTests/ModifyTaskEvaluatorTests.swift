import XCTest
@testable import SwiftTutorApprentice

final class ModifyTaskEvaluatorTests: XCTestCase {
    func testReturnsPassedWhenCodeAndPredictionMatch() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: task.expectedCode,
                prediction: task.expectedOutput,
                task: task
            ),
            .passed
        )
    }

    func testReturnsCodeDoesNotMatchWhenOnlyCodeDiffers() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: "print(\"Goodbye, Swift!\")",
                prediction: task.expectedOutput,
                task: task
            ),
            .codeDoesNotMatch
        )
    }

    func testReturnsPredictionDoesNotMatchWhenOnlyPredictionDiffers() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: task.expectedCode,
                prediction: "Goodbye, Swift!",
                task: task
            ),
            .predictionDoesNotMatch
        )
    }

    func testReturnsBothDoNotMatchWhenCodeAndPredictionDiffer() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: "print(\"Goodbye, Swift!\")",
                prediction: "Goodbye, Swift!",
                task: task
            ),
            .bothDoNotMatch
        )
    }

    func testCodeComparisonNormalizesCRLFToLF() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: "let greeting = \"Hello, Swift!\"\r\nprint(greeting)",
                prediction: task.expectedOutput,
                task: task
            ),
            .passed
        )
    }

    func testCodeComparisonNormalizesLoneCRToLF() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: "let greeting = \"Hello, Swift!\"\rprint(greeting)",
                prediction: task.expectedOutput,
                task: task
            ),
            .passed
        )
    }

    func testCodeComparisonRemovesMultipleFinalLineBreaks() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: task.expectedCode + "\n\n\n",
                prediction: task.expectedOutput,
                task: task
            ),
            .passed
        )
    }

    func testPredictionComparisonTrimsSurroundingWhitespaceAndNewlines() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: task.expectedCode,
                prediction: " \t\nHello, Swift!\r\n ",
                task: task
            ),
            .passed
        )
    }

    func testChangedSpaceInsideStringLiteralFailsCodeComparison() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: "let greeting = \"Hello,  Swift!\"\nprint(greeting)",
                prediction: task.expectedOutput,
                task: task
            ),
            .codeDoesNotMatch
        )
    }

    func testPredictionComparisonIsCaseSensitive() {
        XCTAssertEqual(
            ModifyTaskEvaluator.evaluate(
                code: task.expectedCode,
                prediction: "hello, Swift!",
                task: task
            ),
            .predictionDoesNotMatch
        )
    }

    private var task: ModifyTask {
        ModifyTask(
            id: "change-greeting",
            prompt: "Change the greeting and predict the output.",
            starterCode: "let greeting = \"Hello\"\nprint(greeting)",
            expectedCode: "let greeting = \"Hello, Swift!\"\nprint(greeting)",
            predictionPrompt: "What will appear in the console?",
            expectedOutput: "Hello, Swift!",
            successExplanation: "The updated string is printed.",
            conceptIDs: ["string-literal", "print-call"]
        )
    }
}
