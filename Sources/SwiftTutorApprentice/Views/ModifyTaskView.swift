// ModifyTaskView.swift
// ------------------------------------------------------------
// A replayable guided exercise that asks the learner to make one
// precise code change and predict its output before returning to
// the regular lesson workspace.
// ------------------------------------------------------------

import SwiftUI

struct ModifyTaskView: View {
    let task: ModifyTask
    let existingEditorCode: String
    let onPassed: () -> Void
    let onReplaceEditor: (_ code: String, _ prediction: String) -> Void

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var feedbackIsFocused: Bool
    @State private var code: String
    @State private var prediction = ""
    @State private var result: ModifyTaskResult?
    @State private var hasReportedPass = false
    @State private var showingReplacementConfirmation = false

    init(
        task: ModifyTask,
        existingEditorCode: String,
        onPassed: @escaping () -> Void,
        onReplaceEditor: @escaping (_ code: String, _ prediction: String) -> Void
    ) {
        self.task = task
        self.existingEditorCode = existingEditorCode
        self.onPassed = onPassed
        self.onReplaceEditor = onReplaceEditor
        _code = State(initialValue: task.starterCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    instructions
                    codeEditor
                    predictionEditor

                    Button {
                        checkChange()
                    } label: {
                        Label("Check my change", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .help("Compare your code change and prediction with this task's goal")

                    if let result {
                        feedback(for: result)
                    }
                }
                .frame(maxWidth: 820, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(minWidth: 640, minHeight: 580)
        .onChange(of: code) {
            clearStaleResult()
        }
        .onChange(of: prediction) {
            clearStaleResult()
        }
        .alert(
            "Replace the workspace editor?",
            isPresented: $showingReplacementConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Replace editor", role: .destructive) {
                replaceEditorAndDismiss()
            }
        } message: {
            Text("The workspace already contains different code. Replacing it will overwrite that editor content with this passed change.")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label("Modify", systemImage: "pencil.and.scribble")
                .font(.headline)

            Spacer()

            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .help("Close Modify and keep the current lesson workspace unchanged")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Make one change")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)

            Text(task.prompt)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var codeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code")
                .font(.headline)

            CodeTextView(text: $code)
                .frame(minHeight: 220, idealHeight: 300)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Modify task code editor")
                .accessibilityHint("Edit the starter code to make the requested change")
        }
    }

    private var predictionEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Predict the output")
                .font(.headline)

            Text(task.predictionPrompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextField("Type the expected output", text: $prediction)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .accessibilityLabel("Output prediction")
                .accessibilityHint(task.predictionPrompt)
        }
    }

    private func feedback(for result: ModifyTaskResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text(feedbackTitle(for: result))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: feedbackSymbol(for: result))
                        .foregroundStyle(feedbackColor(for: result))
                }
                .font(.headline)

                Text(feedbackMessage(for: result))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityFocused($feedbackIsFocused)

            if result == .passed {
                Button {
                    requestEditorReplacement()
                } label: {
                    Label("Replace editor with this code", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.borderedProminent)
                .help("Copy this passed code and prediction into the lesson workspace")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(feedbackColor(for: result).opacity(0.11))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(feedbackColor(for: result).opacity(0.5), lineWidth: 1)
        }
    }

    private func checkChange() {
        let newResult = ModifyTaskEvaluator.evaluate(
            code: code,
            prediction: prediction,
            task: task
        )
        result = newResult

        if newResult == .passed, !hasReportedPass {
            hasReportedPass = true
            onPassed()
        }

        Task { @MainActor in
            feedbackIsFocused = true
        }
    }

    private func clearStaleResult() {
        guard result != nil else { return }
        result = nil
        feedbackIsFocused = false
    }

    private func requestEditorReplacement() {
        guard result == .passed else { return }

        if !existingEditorCode.isEmpty, existingEditorCode != code {
            showingReplacementConfirmation = true
        } else {
            replaceEditorAndDismiss()
        }
    }

    private func replaceEditorAndDismiss() {
        guard result == .passed else { return }
        onReplaceEditor(code, prediction)
        dismiss()
    }

    private func feedbackTitle(for result: ModifyTaskResult) -> String {
        switch result {
        case .codeDoesNotMatch:
            return "The prediction matches; check the code"
        case .predictionDoesNotMatch:
            return "The code matches; check the prediction"
        case .bothDoNotMatch:
            return "Keep working on both parts"
        case .passed:
            return "Passed"
        }
    }

    private func feedbackMessage(for result: ModifyTaskResult) -> String {
        switch result {
        case .codeDoesNotMatch:
            return "Your output prediction is right, but the code does not yet match the requested change. Re-read the prompt and compare the edited code carefully."
        case .predictionDoesNotMatch:
            return "Your code makes the requested change. Update the prediction to the exact value that code sends to standard output."
        case .bothDoNotMatch:
            return "The code does not yet make the requested change, and the prediction does not match the expected output. Work through the prompt one part at a time."
        case .passed:
            return task.successExplanation
        }
    }

    private func feedbackSymbol(for result: ModifyTaskResult) -> String {
        switch result {
        case .passed:
            return "checkmark.circle.fill"
        case .codeDoesNotMatch, .predictionDoesNotMatch, .bothDoNotMatch:
            return "exclamationmark.triangle.fill"
        }
    }

    private func feedbackColor(for result: ModifyTaskResult) -> Color {
        switch result {
        case .passed:
            return .green
        case .codeDoesNotMatch, .predictionDoesNotMatch, .bothDoNotMatch:
            return .orange
        }
    }
}
