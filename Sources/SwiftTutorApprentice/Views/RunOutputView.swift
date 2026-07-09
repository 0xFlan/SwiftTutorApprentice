// RunOutputView.swift
// ------------------------------------------------------------
// The bottom bar. Two jobs:
//   1. Prediction: the learner writes what they THINK will happen
//      before running. This builds the habit of reasoning about
//      code instead of guessing.
//   2. Run + Output: shows stdout, stderr, exit code, a plain
//      explanation of what happened, and whether the prediction
//      matched the real output.
// ------------------------------------------------------------

import SwiftUI

struct RunOutputView: View {
    @Binding var prediction: String
    let runResult: RunResult?
    let isRunning: Bool
    let onRun: () -> Void

    var body: some View {
        GeometryReader { geo in
            let narrow = geo.size.width < 560
            VStack(alignment: .leading, spacing: 12) {

                // --- Prediction + Run controls ---
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What do you think this will output?")
                            .font(.subheadline.bold())
                        TextField("Your prediction…", text: $prediction)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .disableAutocorrection(true)
                    }

                    VStack(spacing: 6) {
                        Button(action: onRun) {
                            HStack(spacing: 6) {
                                if isRunning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "play.fill")
                                }
                                Text(isRunning ? "Running…" : "Run")
                            }
                            .frame(minWidth: 90)
                        }
                        .keyboardShortcut("r", modifiers: .command)
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning)

                        Text("⌘R")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                // --- Output area ---
                if let result = runResult {
                    resultsView(result, narrow: narrow)
                } else {
                    Text("Run your code to see stdout, stderr, and the exit code here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Results

    @ViewBuilder
    private func resultsView(_ result: RunResult, narrow: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // If Swift couldn't even launch, say so plainly.
                if let launchError = result.launchError {
                    labeledBlock(
                        title: "Could not run",
                        systemImage: "exclamationmark.triangle.fill",
                        tint: .red,
                        text: launchError
                    )
                } else if narrow {
                    // Narrow window: stack the three streams vertically.
                    VStack(alignment: .leading, spacing: 12) {
                        outputColumn(title: "stdout (standard output)",
                                     text: result.stdout.isEmpty ? "(empty)" : result.stdout, tint: .green)
                        outputColumn(title: "stderr (standard error)",
                                     text: result.stderr.isEmpty ? "(empty)" : result.stderr, tint: .orange)
                        exitCodeBlock(result)
                    }
                } else {
                    // Wide window: three streams side by side.
                    HStack(alignment: .top, spacing: 16) {
                        outputColumn(title: "stdout (standard output)",
                                     text: result.stdout.isEmpty ? "(empty)" : result.stdout, tint: .green)
                        outputColumn(title: "stderr (standard error)",
                                     text: result.stderr.isEmpty ? "(empty)" : result.stderr, tint: .orange)
                        exitCodeBlock(result)
                    }
                }

                Divider()

                // Prediction comparison.
                labeledBlock(
                    title: "Your prediction",
                    systemImage: "brain.head.profile",
                    tint: .blue,
                    text: predictionFeedback(for: result)
                )

                // Plain-language explanation of what happened.
                labeledBlock(
                    title: "What happened",
                    systemImage: "text.book.closed",
                    tint: .accentColor,
                    text: explanation(for: result)
                )
            }
        }
    }

    private func exitCodeBlock(_ result: RunResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("exit code")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("\(result.exitCode)")
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundStyle(result.exitCode == 0 ? .green : .red)
            Text(result.exitCode == 0 ? "success" : "non-zero = problem")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 90, alignment: .leading)
    }

    private func outputColumn(title: String, text: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(8)
                .background(tint.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledBlock(title: String, systemImage: String, tint: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Text helpers

    /// Compare the learner's prediction to the real stdout (loosely).
    private func predictionFeedback(for result: RunResult) -> String {
        let predicted = prediction.trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        if predicted.isEmpty {
            return "You didn't write a prediction this time. Next run, try predicting the output first — it's the most valuable habit in this app."
        }
        if predicted == actual {
            return "Correct. Your prediction matched the program output."
        }
        return """
        Your prediction was different. The actual output was:
        \(actual.isEmpty ? "(nothing was printed to stdout)" : actual)
        """
    }

    /// Explain what the run means in beginner language.
    private func explanation(for result: RunResult) -> String {
        if let launchError = result.launchError {
            return "The program never started. \(launchError)"
        }

        if result.succeeded {
            let printed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return """
            Swift ran main.swift.
            The print function received a String and wrote it to standard output\
            \(printed.isEmpty ? "" : ": \(printed)").
            The process finished with exit code 0, which means success.
            """
        }

        return """
        Swift could not run the program successfully (exit code \(result.exitCode)).
        Read stderr first. stderr is where command-line tools usually write their \
        error messages — it will point at what needs fixing.
        """
    }
}
