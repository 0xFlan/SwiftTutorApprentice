import SwiftUI

enum AICodeReviewSubmitMode: Hashable {
    case disabled
    case enabledDefault
}

@MainActor
final class AICodeReviewSession: ObservableObject {
    let exercise: AICodeReviewExercise
    @Published private(set) var answers: [String: Bool] = [:]
    @Published private(set) var submittedEvaluation: AICodeReviewEvaluation?

    init(exercise: AICodeReviewExercise) {
        self.exercise = exercise
    }

    var submitMode: AICodeReviewSubmitMode {
        guard !exercise.claims.isEmpty,
              exercise.claims.allSatisfy({ answers[$0.id] != nil }) else {
            return .disabled
        }
        return .enabledDefault
    }

    func select(_ answer: Bool, for claimID: String) {
        answers[claimID] = answer
        submittedEvaluation = nil
    }

    func submit() -> AICodeReviewEvaluation? {
        guard submitMode == .enabledDefault else { return nil }
        let evaluation = AICodeReviewEvaluator.evaluate(
            exercise: exercise,
            answers: answers.map { AICodeClaimAnswer(claimID: $0.key, answer: $0.value) }
        )
        guard case .complete = evaluation else { return nil }
        submittedEvaluation = evaluation
        return evaluation
    }

    func retry() {
        answers.removeAll()
        submittedEvaluation = nil
    }
}

struct AICodeReviewView: View {
    let exercise: AICodeReviewExercise
    let onSubmit: (AICodeReviewEvaluation) -> Void
    let onSessionPresented: (AICodeReviewSession, @escaping () -> Void) -> Void

    @MainActor
    init(
        exercise: AICodeReviewExercise,
        onSubmit: @escaping (AICodeReviewEvaluation) -> Void
    ) {
        self.init(
            exercise: exercise,
            onSubmit: onSubmit,
            onSessionPresented: { _, _ in }
        )
    }

    @MainActor
    init(
        exercise: AICodeReviewExercise,
        onSubmit: @escaping (AICodeReviewEvaluation) -> Void,
        onSessionPresented: @escaping (
            AICodeReviewSession,
            @escaping () -> Void
        ) -> Void
    ) {
        self.exercise = exercise
        self.onSubmit = onSubmit
        self.onSessionPresented = onSessionPresented
    }

    var body: some View {
        statefulContent
            .id(exercise)
    }

    private var statefulContent: some View {
        AICodeReviewStatefulView(
            exercise: exercise,
            onSubmit: onSubmit,
            onSessionPresented: onSessionPresented
        )
    }
}

private struct AICodeReviewStatefulView: View {
    let exercise: AICodeReviewExercise
    let onSubmit: (AICodeReviewEvaluation) -> Void
    let onSessionPresented: (AICodeReviewSession, @escaping () -> Void) -> Void

    @StateObject private var session: AICodeReviewSession

    @MainActor
    init(
        exercise: AICodeReviewExercise,
        onSubmit: @escaping (AICodeReviewEvaluation) -> Void,
        onSessionPresented: @escaping (
            AICodeReviewSession,
            @escaping () -> Void
        ) -> Void
    ) {
        self.exercise = exercise
        self.onSubmit = onSubmit
        self.onSessionPresented = onSessionPresented
        _session = StateObject(wrappedValue: AICodeReviewSession(exercise: exercise))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("UNDERSTAND AI CODE")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Text("Verify the generated code")
                    .font(.title3.bold())
                Text(exercise.prompt)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            codeRegion
            claimRegion
            submissionControls

            if case .complete(let feedback, let correctCount, let totalCount, let passed) =
                session.submittedEvaluation {
                feedbackRegion(
                    feedback: feedback,
                    correctCount: correctCount,
                    totalCount: totalCount,
                    passed: passed
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .onAppear {
            onSessionPresented(session, submit)
        }
    }

    private var codeRegion: some View {
        ScrollView([.horizontal, .vertical]) {
            Text(exercise.generatedCode)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Generated code")
                .accessibilityValue(exercise.generatedCode)
                .accessibilityHint("Read-only generated Swift code")
        }
        .frame(minHeight: 82, maxHeight: 150)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var claimRegion: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.claims.enumerated()), id: \.element.id) { index, claim in
                    visualClaim(claim, index: index)
                }
            }
            .padding(.trailing, 6)
        }
        .frame(height: claimRegionHeight)
    }

    private var claimRegionHeight: CGFloat {
        min(max(CGFloat(exercise.claims.count) * 104, 104), 260)
    }

    private func visualClaim(_ claim: AICodeClaim, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Claim \(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(claim.text)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                answerButton(title: "True", answer: true, claim: claim, index: index)
                answerButton(title: "False", answer: false, claim: claim, index: index)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.065), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claim \(index + 1): \(claim.text)")
        .accessibilityValue(selectedAnswerDescription(for: claim.id))
    }

    private func answerButton(
        title: String,
        answer: Bool,
        claim: AICodeClaim,
        index: Int
    ) -> some View {
        Button {
            select(answer, for: claim.id)
        } label: {
            Label(
                title,
                systemImage: session.answers[claim.id] == answer
                    ? "largecircle.fill.circle"
                    : "circle"
            )
        }
        .buttonStyle(.bordered)
        .tint(session.answers[claim.id] == answer ? Color.accentColor : nil)
        .accessibilityLabel("Claim \(index + 1) \(title)")
        .accessibilityValue(answerAccessibilityValue(answer, for: claim.id))
    }

    private var submissionControls: some View {
        HStack(spacing: 10) {
            submitButton
            if session.submittedEvaluation != nil {
                Button("Retry") { session.retry() }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Retry AI code review")
            }
        }
    }

    @ViewBuilder
    private var submitButton: some View {
        if session.submitMode == .enabledDefault {
            Button("Submit", action: submit)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .accessibilityLabel("Submit AI code review")
        } else {
            Button("Submit", action: submit)
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .accessibilityLabel("Submit AI code review")
        }
    }

    private func feedbackRegion(
        feedback: [AICodeClaimFeedback],
        correctCount: Int,
        totalCount: Int,
        passed: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(passed ? "Verified" : "Review the evidence")
                .font(.headline)
            ForEach(Array(feedback.enumerated()), id: \.element.claimID) { index, item in
                VStack(alignment: .leading, spacing: 3) {
                    Text("Claim \(index + 1): \(item.isCorrect ? "Correct" : "Not yet")")
                        .font(.callout.bold())
                    Text(item.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("\(correctCount) of \(totalCount) correct")
                .font(.callout.bold())
            Label(
                "Verify code; do not trust generation blindly",
                systemImage: "checkmark.shield"
            )
            .font(.callout.weight(.medium))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func select(_ answer: Bool, for claimID: String) {
        session.select(answer, for: claimID)
    }

    private func submit() {
        guard let evaluation = session.submit() else { return }
        onSubmit(evaluation)
    }

    private func selectedAnswerDescription(for claimID: String) -> String {
        guard let answer = session.answers[claimID] else { return "No answer selected" }
        return "Selected answer: \(answer ? "True" : "False")"
    }

    private func answerAccessibilityValue(_ answer: Bool, for claimID: String) -> String {
        session.answers[claimID] == answer ? "Selected" : "Not selected"
    }
}
