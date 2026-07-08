// WelcomeView.swift
// ------------------------------------------------------------
// The first-run welcome. Shown once (tracked in AppSettings), it
// explains what the app is and walks through the learning loop so
// a brand-new learner knows what to do.
// ------------------------------------------------------------

import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(icon: "book", title: "Read the lesson",
             detail: "Each lesson explains one small idea, with clickable terms and a breakdown of every symbol."),
        Step(icon: "keyboard", title: "Type the code yourself",
             detail: "You learn by typing it by hand — not by copying. The Live Coach reacts as you go."),
        Step(icon: "brain.head.profile", title: "Predict the output",
             detail: "Before running, guess what it will print. This is the habit that builds real understanding."),
        Step(icon: "play.circle", title: "Run it for real",
             detail: "The app runs your Swift locally and shows the actual output, errors, and exit code — then explains them.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "swift")
                    .font(.system(size: 44))
                    .foregroundStyle(.orange)
                Text("Welcome to SwiftTutor Apprentice")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("A calm, hands-on way to learn Swift — everything happens right here in the app.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 32)
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: step.icon)
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title).font(.headline)
                            Text(step.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(28)

            Divider()

            HStack {
                Text("Start with Lesson 1. Work at your own pace.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: onStart) {
                    Text("Start learning")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 560, height: 560)
    }
}
