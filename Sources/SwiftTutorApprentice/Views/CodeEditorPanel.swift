// CodeEditorPanel.swift
// ------------------------------------------------------------
// The middle column. A basic code editor built on SwiftUI's
// TextEditor. No syntax highlighting yet — just a monospaced
// place to type Swift by hand.
//
// TODO: Add lightweight syntax highlighting (kept out of the MVP
//       on purpose to stay simple).
// ------------------------------------------------------------

import SwiftUI

struct CodeEditorPanel: View {
    // A two-way binding: changes here update ContentView's `code`,
    // and vice-versa. That's what `@Binding` means.
    @Binding var code: String

    /// Faint text shown when the editor is empty (this lesson's starter).
    let placeholder: String

    /// Reset the editor back to the lesson's starter line.
    let onInsertStarter: () -> Void

    /// False while a walkthrough is auto-typing the code.
    var isEditable: Bool = true

    @State private var showingParsons = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Code Editor")
                    .font(.headline)
                Spacer()
                if isEditable && ParsonsView.isAvailable(for: placeholder) {
                    Button {
                        showingParsons = true
                    } label: {
                        Label("Arrange first", systemImage: "arrow.up.arrow.down")
                    }
                    .help("Practice: drag the lines into the right order before writing it yourself")
                }
                Button {
                    onInsertStarter()
                } label: {
                    Label("Insert starter", systemImage: "text.insert")
                }
                .help("Fill the editor with this lesson's starter code")
                .disabled(!isEditable)
            }

            Text("Type Swift here. This is the file that gets run.")
                .font(.caption)
                .foregroundStyle(.secondary)

            CodeTextView(text: $code, isEditable: isEditable)
                .frame(minHeight: 160)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                // Faint placeholder showing the starter code when empty.
                .overlay(alignment: .topLeading) {
                    if code.isEmpty {
                        Text(placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary.opacity(0.45))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            Text("Saved to ~/Developer/SwiftTutorApprentice/Workspace/main.swift when you Run.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $showingParsons) {
            ParsonsView(correctCode: placeholder) { arranged in
                code = arranged
            }
        }
    }
}
