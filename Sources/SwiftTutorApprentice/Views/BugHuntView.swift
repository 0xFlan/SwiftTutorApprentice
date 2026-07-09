// BugHuntView.swift
// ------------------------------------------------------------
// A "find the bug" / self-explanation exercise. We take the
// lesson's correct code, inject ONE common beginner mistake, and
// ask the learner to explain — in their own words — what's wrong
// and how they'd fix it BEFORE revealing the answer. Explaining a
// broken example (then getting immediate feedback) is one of the
// best-supported ways to deepen understanding and transfer.
// (Evidence: JISE 2024; ACM 10.1145/3732791 — see docs/learning-evidence.md.)
//
// The bug is derived automatically from the lesson's code, so no
// per-lesson authoring is needed. Because WE choose the mutation,
// the explanation of what's wrong is always accurate.
//
// "Try it in the editor" drops the broken code into the main editor
// so the learner can fix it and Run to see the real Swift error.
// ------------------------------------------------------------

import SwiftUI

/// Injects one deterministic beginner bug into otherwise-correct code.
enum BugInjector {
    struct Bug {
        let code: String        // the broken code
        let explanation: String // why it's broken + how to fix
    }

    /// Try to break the code in one realistic, always-failing way.
    /// Ordered by how common the mistake is for beginners.
    static func inject(into correct: String) -> Bug? {
        // 1) Drop a closing quotation mark → unterminated string literal.
        let quotes = correct.filter { $0 == "\"" }.count
        if quotes >= 2, quotes % 2 == 0, let i = correct.lastIndex(of: "\"") {
            var broken = correct
            broken.remove(at: i)
            return Bug(
                code: broken,
                explanation: """
                A closing quotation mark is missing. In Swift, text (a String) must \
                be wrapped in a matching pair of quotation marks — one to open it and \
                one to close it. With one missing, Swift keeps reading to the end of \
                the line looking for the closing " and never finds it, so it reports \
                an "unterminated string literal". Fix: add the missing ".
                """
            )
        }

        // 2) Drop a closing parenthesis → unbalanced parentheses.
        let openParens = correct.filter { $0 == "(" }.count
        let closeParens = correct.filter { $0 == ")" }.count
        if openParens >= 1, openParens == closeParens, let i = correct.lastIndex(of: ")") {
            var broken = correct
            broken.remove(at: i)
            return Bug(
                code: broken,
                explanation: """
                A closing parenthesis ) is missing. Every opening ( needs a matching \
                ). Without it, Swift can't tell where the function's input ends, so it \
                reports an error about an expected ')'. Fix: add the missing ).
                """
            )
        }

        // 3) Drop a closing brace → unbalanced braces.
        let openBraces = correct.filter { $0 == "{" }.count
        let closeBraces = correct.filter { $0 == "}" }.count
        if openBraces >= 1, openBraces == closeBraces, let i = correct.lastIndex(of: "}") {
            var broken = correct
            broken.remove(at: i)
            return Bug(
                code: broken,
                explanation: """
                A closing brace } is missing. Every { that opens a block of code needs \
                a matching } to close it. Fix: add the missing }.
                """
            )
        }

        return nil
    }

    static func canInject(_ correct: String) -> Bool {
        inject(into: correct) != nil
    }
}

struct BugHuntView: View {
    let correctCode: String
    /// Called to drop the broken code into the main editor (to fix + run).
    let onLoadBuggy: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private let bug: BugInjector.Bug?
    @State private var explanation = ""
    @State private var revealed = false

    init(correctCode: String, onLoadBuggy: @escaping (String) -> Void) {
        self.correctCode = correctCode
        self.onLoadBuggy = onLoadBuggy
        self.bug = BugInjector.inject(into: correctCode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Find the Bug")
                    .font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            if let bug {
                content(bug)
            } else {
                Text("No bug exercise is available for this lesson.")
                    .foregroundStyle(.secondary)
                    .padding(16)
            }
        }
        .frame(width: 560, height: 560)
    }

    @ViewBuilder
    private func content(_ bug: BugInjector.Bug) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("This code has exactly one bug. Read it and — in your own words — explain what's wrong and how you'd fix it. Then reveal the answer.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                codeBlock(bug.code, tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your explanation")
                        .font(.subheadline.bold())
                    TextEditor(text: $explanation)
                        .font(.callout)
                        .frame(minHeight: 72)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
                        .disableAutocorrection(false)
                }

                HStack(spacing: 10) {
                    Button {
                        revealed = true
                    } label: {
                        Label("Reveal answer", systemImage: "lightbulb")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        onLoadBuggy(bug.code)
                        dismiss()
                    } label: {
                        Label("Try it in the editor", systemImage: "pencil.and.outline")
                    }
                    .help("Load the broken code into the editor so you can fix it and Run to see the real error")

                    Spacer()
                }

                if revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What's wrong", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        Text(bug.explanation)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().padding(.vertical, 2)

                        Label("Corrected code", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                        codeBlock(correctCode, tint: .green)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private func codeBlock(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .background(tint.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
