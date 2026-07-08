// SettingsView.swift
// ------------------------------------------------------------
// In-app settings, shown as a sheet — no need to leave the app.
// For now this is just the optional AI coach.
// ------------------------------------------------------------

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.title3.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Toggle(isOn: $settings.aiEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable the optional AI coach")
                                .font(.headline)
                            Text("Adds an “Ask the AI coach” button to the Live Coach panel.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.aiEnabled {
                        Picker("AI source", selection: $settings.aiProvider) {
                            Text("Command-line tool (e.g. claude CLI)").tag("cli")
                            Text("Anthropic API key").tag("api")
                        }
                        .pickerStyle(.radioGroup)

                        if settings.aiProvider == "cli" {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AI command")
                                    .font(.subheadline.bold())
                                TextField("claude", text: $settings.aiCommand)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Text("""
                                The command-line tool to run for AI help. The app calls it \
                                in non-interactive mode: `\(settings.aiCommand.isEmpty ? "claude" : settings.aiCommand) -p "…"`. \
                                Enter a name (found in ~/.local/bin, Homebrew, etc.) or a full path.
                                """)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Anthropic API key")
                                    .font(.subheadline.bold())
                                SecureField("sk-ant-…", text: $settings.apiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Text("Model")
                                    .font(.subheadline.bold())
                                TextField("claude-opus-4-8", text: $settings.apiModel)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                                Text("""
                                The app calls the Anthropic Messages API directly over the \
                                network. Your key is stored locally on this Mac (in app \
                                preferences).
                                """)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        Label {
                            Text("Privacy: when you press “Ask the AI coach”, your current lesson and the code you typed are sent to the tool or API you selected. It's off unless you enable it and press the button.")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lock.shield")
                        }
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
        }
        .frame(width: 500, height: 480)
    }
}
