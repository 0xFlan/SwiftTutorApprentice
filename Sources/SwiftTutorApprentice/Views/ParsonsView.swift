// ParsonsView.swift
// ------------------------------------------------------------
// A "Parsons problem": the lesson's code, split into lines and
// SCRAMBLED. The learner drags the lines into the correct order,
// then checks. This is a lower-load practice step that bridges the
// jump from reading a worked example to writing code from scratch —
// especially helpful for beginners who don't yet know where to start.
//
// (Evidence: Ericson, Margulieux & Rick 2017; see docs/learning-evidence.md.
// Deliberately NO distractor lines — distractors reduce novice
// efficiency, per Harms et al. 2016.)
//
// The problem is derived automatically from the lesson's starter code,
// so every multi-line lesson gets one for free.
// ------------------------------------------------------------

import SwiftUI

struct ParsonsView: View {
    /// The correct code (the lesson's starter code).
    let correctCode: String
    /// Called with the correct code when the learner chooses to use it.
    let onUseInEditor: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private struct Line: Identifiable, Equatable {
        let id: Int      // original position — stable and unique even if text repeats
        let text: String
    }

    @State private var lines: [Line]
    @State private var checked = false

    init(correctCode: String, onUseInEditor: @escaping (String) -> Void) {
        self.correctCode = correctCode
        self.onUseInEditor = onUseInEditor
        _lines = State(initialValue: Self.scrambled(from: correctCode))
    }

    /// The correct ordering of non-empty lines.
    private var correctLines: [String] { Self.codeLines(correctCode) }

    private var isCorrect: Bool { lines.map(\.text) == correctLines }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Arrange the Code")
                    .font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Drag the lines into the correct order, then press Check. This is practice — no typing required.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                List {
                    ForEach(lines) { line in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.tertiary)
                            Text(line.text)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove { indices, newOffset in
                        lines.move(fromOffsets: indices, toOffset: newOffset)
                        checked = false
                    }
                }
                .frame(minHeight: 180)

                // Fallback reorder controls (work even if drag is awkward):
                // select nothing; instead show per-row up/down via context is
                // heavier — so we keep drag as primary and offer Shuffle/Check.
                HStack(spacing: 10) {
                    Button {
                        checked = true
                    } label: {
                        Label("Check", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        lines = Self.scrambled(from: correctCode)
                        checked = false
                    } label: {
                        Label("Shuffle", systemImage: "shuffle")
                    }

                    Spacer()

                    if checked && isCorrect {
                        Button {
                            onUseInEditor(correctCode)
                            dismiss()
                        } label: {
                            Label("Use this in the editor", systemImage: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }

                if checked {
                    if isCorrect {
                        Label("Correct! That's the right order.", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not quite — keep rearranging and check again.", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 520, height: 460)
    }

    // MARK: - Helpers

    /// The non-empty lines of the code, in order (verbatim, keeping indentation).
    private static func codeLines(_ code: String) -> [String] {
        code.split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Split into lines and shuffle, ensuring the result isn't already correct.
    private static func scrambled(from code: String) -> [Line] {
        let correct = codeLines(code)
        var order = Array(correct.indices)
        if correct.count > 1 {
            var attempts = 0
            repeat {
                order.shuffle()
                attempts += 1
            } while order == Array(correct.indices) && attempts < 8
        }
        return order.map { Line(id: $0, text: correct[$0]) }
    }

    /// Whether a Parsons problem is worthwhile for this code (2+ lines).
    static func isAvailable(for code: String) -> Bool {
        codeLines(code).count >= 2
    }
}
