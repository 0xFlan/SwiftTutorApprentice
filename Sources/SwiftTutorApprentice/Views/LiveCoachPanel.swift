// LiveCoachPanel.swift
// ------------------------------------------------------------
// The right column. Shows the rule-based Live Coach's feedback
// about whatever is currently in the editor (updates live as the
// learner types).
//
// If the OPTIONAL AI coach is turned on in Settings, this panel
// also shows an "Ask the AI coach" button and its reply. The
// rule-based coach is always present; AI is extra.
// ------------------------------------------------------------

import SwiftUI

struct LiveCoachPanel: View {
    let feedback: String

    // Optional AI coach.
    let aiEnabled: Bool
    let isAskingAI: Bool
    let aiResponse: String?
    let aiError: String?
    let onAskAI: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
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

                if aiEnabled {
                    aiSection
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 2)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("AI coach")
                    .font(.headline)
            }

            Button(action: onAskAI) {
                HStack(spacing: 6) {
                    if isAskingAI {
                        ProgressView().controlSize(.small)
                        Text("Asking…")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Ask the AI coach")
                    }
                }
            }
            .disabled(isAskingAI)
            .help("Send the current lesson and your code to your AI CLI for extra explanation")

            if let aiError {
                Text(aiError)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if let aiResponse {
                Text(aiResponse)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.purple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
