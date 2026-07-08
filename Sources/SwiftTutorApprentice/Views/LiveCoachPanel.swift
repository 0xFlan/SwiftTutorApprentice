// LiveCoachPanel.swift
// ------------------------------------------------------------
// The right column. Shows the rule-based Live Coach's feedback
// about whatever is currently in the editor. It updates live as
// the learner types.
// ------------------------------------------------------------

import SwiftUI

struct LiveCoachPanel: View {
    /// The feedback text, computed by ContentView from the editor code.
    let feedback: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    Text("Live Coach")
                        .font(.headline)
                }

                Text("Feedback about what you typed:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(feedback)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }
}
