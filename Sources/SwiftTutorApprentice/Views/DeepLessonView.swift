// DeepLessonView.swift
// ------------------------------------------------------------
// The replayable, concept-first sheet shown before the existing
// lesson workspace. It explains, contrasts, and checks recall.
// ------------------------------------------------------------

import SwiftUI

struct DeepLessonView: View {
    let lesson: Lesson
    let content: LessonDeepContent
    let onViewed: () -> Void
    let onRecallAnswer: (_ questionID: String, _ wasCorrect: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var headingIsFocused: Bool
    @State private var reportedViewed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    lessonHeading

                    conceptSection

                    Divider()

                    SyntaxMicroscopeView(tokens: content.microscopeTokens)

                    Divider()

                    recallSection
                }
                .frame(maxWidth: 900, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Divider()

            bottomBar
        }
        .frame(minWidth: 700, minHeight: 620)
        .onAppear {
            reportViewedOnce()
            Task { @MainActor in
                headingIsFocused = true
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label("Deep Lesson", systemImage: "book.pages")
                .font(.headline)

            Spacer()

            Button {
                dismiss()
            } label: {
                Label("Skip to workspace", systemImage: "arrow.right")
            }
            .keyboardShortcut(.cancelAction)
            .help("Close the Deep Lesson and go directly to the coding workspace")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var lessonHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lesson \(lesson.id) · \(lesson.title)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(content.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingIsFocused)

            Text(content.introduction)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var conceptSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Concepts")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(content.segments.enumerated()), id: \.element.id) { index, segment in
                if index > 0 {
                    Divider()
                }

                conceptSegment(segment, number: index + 1)
            }
        }
    }

    private func conceptSegment(_ segment: DeepLessonSegment, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Concept \(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(segment.title)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(segment.explanation)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            examples(for: segment)
        }
    }

    @ViewBuilder
    private func examples(for segment: DeepLessonSegment) -> some View {
        if let correctCode = segment.correctCode,
           let wrongCode = segment.wrongCode {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    example(
                        title: "Correct example",
                        symbol: "checkmark.circle.fill",
                        code: correctCode,
                        accent: .green
                    )

                    example(
                        title: "Wrong variant",
                        symbol: "xmark.circle.fill",
                        code: wrongCode,
                        explanation: segment.wrongExplanation,
                        accent: .red
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    example(
                        title: "Correct example",
                        symbol: "checkmark.circle.fill",
                        code: correctCode,
                        accent: .green
                    )

                    example(
                        title: "Wrong variant",
                        symbol: "xmark.circle.fill",
                        code: wrongCode,
                        explanation: segment.wrongExplanation,
                        accent: .red
                    )
                }
            }
        } else if let correctCode = segment.correctCode {
            example(
                title: "Correct example",
                symbol: "checkmark.circle.fill",
                code: correctCode,
                accent: .green
            )
        } else if let wrongCode = segment.wrongCode {
            example(
                title: "Wrong variant",
                symbol: "xmark.circle.fill",
                code: wrongCode,
                explanation: segment.wrongExplanation,
                accent: .red
            )
        }
    }

    private func example(
        title: String,
        symbol: String,
        code: String,
        explanation: String? = nil,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.bold())
                .foregroundStyle(accent)

            Text(code)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(accent.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            if let explanation {
                Label {
                    Text(explanation)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 260, maxWidth: .infinity, alignment: .topLeading)
    }

    private var recallSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Recall")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                Text("Choose one answer for each question. Your first choice is final for this visit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(content.recallQuestions.enumerated()), id: \.element.id) { index, question in
                RecallQuestionCard(
                    question: question,
                    number: index + 1,
                    onAnswer: onRecallAnswer
                )
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Text("You can replay this Deep Lesson from the lesson workspace.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Label("Continue to practice", systemImage: "arrow.right.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .help("Close the Deep Lesson and continue to the coding workspace")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func reportViewedOnce() {
        guard !reportedViewed else { return }
        reportedViewed = true
        onViewed()
    }
}

private struct RecallQuestionCard: View {
    let question: RecallQuestion
    let number: Int
    let onAnswer: (_ questionID: String, _ wasCorrect: Bool) -> Void

    @State private var selectedChoiceIndex: Int?

    private var answeredCorrectly: Bool {
        selectedChoiceIndex == question.correctChoiceIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Question \(number)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(question.prompt)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(question.choices.indices, id: \.self) { index in
                    choiceButton(at: index)
                }
            }

            if selectedChoiceIndex != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        answeredCorrectly ? "Correct" : "Not quite",
                        systemImage: answeredCorrectly
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(answeredCorrectly ? Color.green : Color.orange)

                    Text(question.explanation)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(.top, 2)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 10)
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
        .disabled(selectedChoiceIndex != nil)
        .accessibilityLabel(Text("Answer \(index + 1): \(choice)"))
        .accessibilityValue(choiceAccessibilityValue(for: index))
        .help(selectedChoiceIndex == nil ? "Choose this answer" : "This question is locked")
    }

    private func selectChoice(at index: Int) {
        guard selectedChoiceIndex == nil else { return }
        selectedChoiceIndex = index
        onAnswer(question.id, index == question.correctChoiceIndex)
    }

    private func choiceAccessibilityValue(for index: Int) -> Text {
        guard let selectedChoiceIndex else {
            return Text("Not selected")
        }

        if selectedChoiceIndex == index {
            return Text(answeredCorrectly ? "Selected, correct" : "Selected, not quite")
        }

        return Text("Not selected, question locked")
    }
}
