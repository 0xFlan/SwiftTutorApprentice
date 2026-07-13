import XCTest
@testable import SwiftTutorApprentice

final class AICodeReviewEvaluatorTests: XCTestCase {
    func testIncompleteEvaluationReportsEveryMissingClaimIDInSortedOrder() {
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: Self.exercise,
            answers: [AICodeClaimAnswer(claimID: "claim-b", answer: false)]
        )

        XCTAssertEqual(
            evaluation,
            .incomplete(missingClaimIDs: ["claim-a", "claim-c"])
        )
    }

    func testCompleteEvaluationReturnsAuthoredFeedbackCountAndPass() {
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: Self.exercise,
            answers: [
                AICodeClaimAnswer(claimID: "claim-c", answer: true),
                AICodeClaimAnswer(claimID: "claim-a", answer: true),
                AICodeClaimAnswer(claimID: "claim-b", answer: false)
            ]
        )

        XCTAssertEqual(
            evaluation,
            .complete(
                feedback: [
                    AICodeClaimFeedback(
                        claimID: "claim-c",
                        claimText: "The output is 2.",
                        learnerAnswer: true,
                        correctAnswer: true,
                        isCorrect: true,
                        explanation: "print receives the stored integer."
                    ),
                    AICodeClaimFeedback(
                        claimID: "claim-a",
                        claimText: "The value is stored.",
                        learnerAnswer: true,
                        correctAnswer: true,
                        isCorrect: true,
                        explanation: "The declaration creates the binding."
                    ),
                    AICodeClaimFeedback(
                        claimID: "claim-b",
                        claimText: "The name is printed literally.",
                        learnerAnswer: false,
                        correctAnswer: false,
                        isCorrect: true,
                        explanation: "The unquoted name is looked up first."
                    )
                ],
                correctCount: 3,
                totalCount: 3,
                passed: true
            )
        )
    }

    func testCompleteEvaluationPassesOnlyWhenEveryClaimIsCorrect() {
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: Self.exercise,
            answers: [
                AICodeClaimAnswer(claimID: "claim-a", answer: false),
                AICodeClaimAnswer(claimID: "claim-b", answer: false),
                AICodeClaimAnswer(claimID: "claim-c", answer: true)
            ]
        )

        guard case .complete(let feedback, let correctCount, let totalCount, let passed) = evaluation else {
            return XCTFail("Expected a complete evaluation, got \(evaluation)")
        }
        XCTAssertEqual(correctCount, 2)
        XCTAssertEqual(totalCount, 3)
        XCTAssertFalse(passed)
        XCTAssertEqual(feedback.map(\.claimID), ["claim-c", "claim-a", "claim-b"])
        XCTAssertEqual(feedback[1].learnerAnswer, false)
        XCTAssertEqual(feedback[1].correctAnswer, true)
        XCTAssertFalse(feedback[1].isCorrect)
        XCTAssertEqual(feedback[1].explanation, "The declaration creates the binding.")
    }

    func testExtraAndDuplicateAnswerIDsAreRejectedExactly() {
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: Self.exercise,
            answers: [
                AICodeClaimAnswer(claimID: "claim-a", answer: true),
                AICodeClaimAnswer(claimID: "claim-a", answer: false),
                AICodeClaimAnswer(claimID: "unknown-z", answer: true),
                AICodeClaimAnswer(claimID: "unknown-a", answer: false)
            ]
        )

        XCTAssertEqual(
            evaluation,
            .rejected(
                extraClaimIDs: ["unknown-a", "unknown-z"],
                duplicateClaimIDs: ["claim-a"]
            )
        )
    }

    func testDuplicateUnknownAnswerIDIsBothExtraAndDuplicate() {
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: Self.exercise,
            answers: [
                AICodeClaimAnswer(claimID: "unknown", answer: true),
                AICodeClaimAnswer(claimID: "unknown", answer: false)
            ]
        )

        XCTAssertEqual(
            evaluation,
            .rejected(extraClaimIDs: ["unknown"], duplicateClaimIDs: ["unknown"])
        )
    }

    private static let exercise = AICodeReviewExercise(
        id: "review",
        prompt: "Check each claim.",
        generatedCode: "let value = 2\nprint(value)",
        claims: [
            AICodeClaim(
                id: "claim-c",
                text: "The output is 2.",
                isCorrect: true,
                explanation: "print receives the stored integer."
            ),
            AICodeClaim(
                id: "claim-a",
                text: "The value is stored.",
                isCorrect: true,
                explanation: "The declaration creates the binding."
            ),
            AICodeClaim(
                id: "claim-b",
                text: "The name is printed literally.",
                isCorrect: false,
                explanation: "The unquoted name is looked up first."
            )
        ],
        conceptIDs: []
    )
}
