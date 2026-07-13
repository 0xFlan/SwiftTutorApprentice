import Foundation

struct AICodeClaimAnswer: Hashable {
    let claimID: String
    let answer: Bool
}

struct AICodeClaimFeedback: Hashable {
    let claimID: String
    let claimText: String
    let learnerAnswer: Bool
    let correctAnswer: Bool
    let isCorrect: Bool
    let explanation: String
}

enum AICodeReviewEvaluation: Hashable {
    case incomplete(missingClaimIDs: [String])
    case rejected(extraClaimIDs: [String], duplicateClaimIDs: [String])
    case complete(
        feedback: [AICodeClaimFeedback],
        correctCount: Int,
        totalCount: Int,
        passed: Bool
    )
}

enum AICodeReviewEvaluator {
    static func evaluate(
        exercise: AICodeReviewExercise,
        answers: [AICodeClaimAnswer]
    ) -> AICodeReviewEvaluation {
        let expectedIDs = Set(exercise.claims.map(\.id))
        let groupedAnswers = Dictionary(grouping: answers, by: \.claimID)
        let actualIDs = Set(groupedAnswers.keys)
        let extraIDs = actualIDs.subtracting(expectedIDs).sorted()
        let duplicateIDs = groupedAnswers
            .filter { $0.value.count > 1 }
            .map(\.key)
            .sorted()

        guard extraIDs.isEmpty, duplicateIDs.isEmpty else {
            return .rejected(
                extraClaimIDs: extraIDs,
                duplicateClaimIDs: duplicateIDs
            )
        }

        let missingIDs = expectedIDs.subtracting(actualIDs).sorted()
        guard missingIDs.isEmpty else {
            return .incomplete(missingClaimIDs: missingIDs)
        }

        let answersByID = Dictionary(
            uniqueKeysWithValues: answers.map { ($0.claimID, $0.answer) }
        )
        let feedback = exercise.claims
            .compactMap { claim -> AICodeClaimFeedback? in
                guard let learnerAnswer = answersByID[claim.id] else { return nil }
                return AICodeClaimFeedback(
                    claimID: claim.id,
                    claimText: claim.text,
                    learnerAnswer: learnerAnswer,
                    correctAnswer: claim.isCorrect,
                    isCorrect: learnerAnswer == claim.isCorrect,
                    explanation: claim.explanation
                )
            }
        let correctCount = feedback.filter(\.isCorrect).count
        return .complete(
            feedback: feedback,
            correctCount: correctCount,
            totalCount: feedback.count,
            passed: correctCount == feedback.count
        )
    }
}
