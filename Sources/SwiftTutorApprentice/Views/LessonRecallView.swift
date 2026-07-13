import SwiftUI

struct LessonRecallView: View {
    private enum RequestedFocusTarget: String {
        case firstChoice = "choice-0"
        case continueAction = "continue"
        case feedback
    }

    let question: RecallQuestion
    let number: Int?
    let focusGeneration: UInt64
    let showsContinue: Bool
    let persistedWasCorrect: Bool?
    let onAnswer: (_ questionID: String, _ wasCorrect: Bool) -> Void
    let onFocusApplied: (_ generation: UInt64) -> Void
    let onContinue: () -> Void

    @State private var selectedChoiceIndex: Int?
    @State private var requestedFocusTarget: RequestedFocusTarget?
    @FocusState private var focusedChoiceIndex: Int?
    @FocusState private var continueIsFocused: Bool
    @FocusState private var feedbackHasKeyboardFocus: Bool
    @AccessibilityFocusState private var feedbackIsFocused: Bool

    init(
        question: RecallQuestion,
        number: Int? = nil,
        focusGeneration: UInt64 = 0,
        showsContinue: Bool = false,
        persistedWasCorrect: Bool? = nil,
        onAnswer: @escaping (_ questionID: String, _ wasCorrect: Bool) -> Void,
        onFocusApplied: @escaping (_ generation: UInt64) -> Void = { _ in },
        onContinue: @escaping () -> Void = {}
    ) {
        self.question = question
        self.number = number
        self.focusGeneration = focusGeneration
        self.showsContinue = showsContinue
        self.persistedWasCorrect = persistedWasCorrect
        self.onAnswer = onAnswer
        self.onFocusApplied = onFocusApplied
        self.onContinue = onContinue
    }

    private var isAnswered: Bool {
        persistedWasCorrect != nil || selectedChoiceIndex != nil
    }

    private var answeredCorrectly: Bool {
        if let persistedWasCorrect {
            return persistedWasCorrect
        }
        return selectedChoiceIndex == question.correctChoiceIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(number.map { "Question \($0)" } ?? "Recall")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(question.choices.indices, id: \.self) { index in
                    choiceButton(at: index)
                        .focused($focusedChoiceIndex, equals: index)
                }
            }

            if isAnswered {
                VStack(alignment: .leading, spacing: 8) {
                    Label {
                        Text(answeredCorrectly ? "Correct" : "Not quite")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(
                            systemName: answeredCorrectly
                                ? "checkmark.circle.fill"
                                : "xmark.circle.fill"
                        )
                        .foregroundStyle(answeredCorrectly ? Color.green : Color.orange)
                    }
                    .font(.headline)

                    Text(question.explanation)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .background {
                            RuntimeViewMarker(identifier: "lesson-recall-explanation")
                        }

                    if showsContinue {
                        Button("Continue", action: onContinue)
                            .buttonStyle(.borderedProminent)
                            .help("Continue to Modify or the Practice and Run workspace")
                            .focused($continueIsFocused)
                            .background {
                                RuntimeViewMarker(identifier: "lesson-recall-continue")
                            }
                    }
                }
                .padding(.top, 2)
                .accessibilityElement(children: .contain)
                .accessibilityFocused($feedbackIsFocused)
                .focusable(!showsContinue)
                .focused($feedbackHasKeyboardFocus)
                .background {
                    ZStack {
                        RuntimeViewMarker(identifier: "lesson-recall-answered")
                        RuntimeViewMarker(
                            identifier: answeredCorrectly
                                ? "lesson-recall-correct"
                                : "lesson-recall-incorrect"
                        )
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .id("lesson-recall-\(question.id)")
        .accessibilityIdentifier("lesson-recall-\(question.id)")
        .background {
            if let requestedFocusTarget {
                RuntimeViewMarker(
                    identifier: "lesson-recall-focus-target-\(requestedFocusTarget.rawValue)"
                )
            }
        }
        .task(id: focusGeneration) {
            guard focusGeneration > 0 else { return }
            await Task.yield()
            focusedChoiceIndex = nil
            continueIsFocused = false
            feedbackHasKeyboardFocus = false
            let target: RequestedFocusTarget
            if !isAnswered {
                target = .firstChoice
                focusedChoiceIndex = 0
            } else if showsContinue {
                target = .continueAction
                continueIsFocused = true
            } else {
                target = .feedback
                feedbackHasKeyboardFocus = true
            }
            requestedFocusTarget = target
            await Task.yield()
            onFocusApplied(focusGeneration)
        }
    }

    private func choiceButton(at index: Int) -> some View {
        let choice = question.choices[index]

        return Button {
            selectChoice(at: index)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(index + 1).")
                    .font(.body.monospacedDigit().bold())

                Text(choice)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if selectedChoiceIndex == index {
                    Image(
                        systemName: answeredCorrectly
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .foregroundStyle(answeredCorrectly ? Color.green : Color.orange)
                    .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(isAnswered)
        .accessibilityLabel(Text("Answer \(index + 1): \(choice)"))
        .accessibilityValue(choiceAccessibilityValue(for: index))
        .help(isAnswered ? "This question is locked" : "Choose this answer")
        .background {
            ZStack {
                if isAnswered {
                    RuntimeViewMarker(identifier: "lesson-recall-choice-locked")
                }
                if selectedChoiceIndex == index {
                    RuntimeViewMarker(identifier: "lesson-recall-choice-selected")
                }
            }
        }
    }

    private func selectChoice(at index: Int) {
        guard !isAnswered else { return }
        selectedChoiceIndex = index
        onAnswer(question.id, index == question.correctChoiceIndex)
        Task { @MainActor in
            feedbackIsFocused = true
        }
    }

    private func choiceAccessibilityValue(for index: Int) -> Text {
        guard let selectedChoiceIndex else {
            if let persistedWasCorrect {
                return Text(
                    persistedWasCorrect
                        ? "Not selected, question locked after a correct answer"
                        : "Not selected, question locked after an incorrect answer"
                )
            }
            return Text("Not selected")
        }

        if selectedChoiceIndex == index {
            return Text(answeredCorrectly ? "Selected, correct" : "Selected, not quite")
        }

        return Text("Not selected, question locked")
    }
}
