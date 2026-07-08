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

    /// Reset the editor back to the lesson's starter line.
    let onInsertStarter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Code Editor")
                    .font(.headline)
                Spacer()
                Button {
                    onInsertStarter()
                } label: {
                    Label("Insert starter", systemImage: "text.insert")
                }
                .help("Fill the editor with print(\"Hello, Swift!\")")
            }

            Text("Type Swift here. This is the file that gets run.")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                // Beginners shouldn't fight autocorrect while typing code.
                .disableAutocorrection(true)

            Text("Saved to ~/Developer/SwiftTutorApprentice/Workspace/main.swift when you Run.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}
