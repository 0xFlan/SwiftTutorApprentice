// AppSettings.swift
// ------------------------------------------------------------
// Small, persistent app preferences. For the MVP this is just the
// optional AI coach: whether it's on, and which command-line tool
// to call for it.
//
// The AI coach is OFF by default. When on, the app asks a local
// command-line tool (your `claude` CLI by default) for extra
// explanations. Nothing is sent anywhere unless you turn this on
// and press the button.
//
// Preferences are saved with UserDefaults, so they persist between
// launches with no file management on your part.
// ------------------------------------------------------------

import Foundation

final class AppSettings: ObservableObject {

    private enum Keys {
        static let aiEnabled = "aiEnabled"
        static let aiCommand = "aiCommand"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let aiProvider = "aiProvider"
        static let apiKey = "apiKey"
        static let apiModel = "apiModel"
    }

    /// How the optional AI coach reaches an AI: "cli" (default) or "api".
    @Published var aiProvider: String {
        didSet { UserDefaults.standard.set(aiProvider, forKey: Keys.aiProvider) }
    }

    /// Anthropic API key, used when aiProvider == "api".
    /// Stored in UserDefaults for simplicity on this personal app. For a
    /// shipped app you'd keep this in the Keychain instead.
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: Keys.apiKey) }
    }

    /// Model id for the API provider.
    @Published var apiModel: String {
        didSet { UserDefaults.standard.set(apiModel, forKey: Keys.apiModel) }
    }

    /// Whether the optional AI coach is available. Off by default.
    @Published var aiEnabled: Bool {
        didSet { UserDefaults.standard.set(aiEnabled, forKey: Keys.aiEnabled) }
    }

    /// The command-line tool to invoke for AI help (e.g. "claude").
    /// You can also enter an absolute path.
    @Published var aiCommand: String {
        didSet { UserDefaults.standard.set(aiCommand, forKey: Keys.aiCommand) }
    }

    /// Whether the learner has seen the first-run welcome.
    @Published var hasSeenWelcome: Bool {
        didSet { UserDefaults.standard.set(hasSeenWelcome, forKey: Keys.hasSeenWelcome) }
    }

    init() {
        let defaults = UserDefaults.standard
        aiEnabled = defaults.bool(forKey: Keys.aiEnabled) // false if unset
        aiCommand = defaults.string(forKey: Keys.aiCommand) ?? "claude"
        hasSeenWelcome = defaults.bool(forKey: Keys.hasSeenWelcome) // false if unset
        aiProvider = defaults.string(forKey: Keys.aiProvider) ?? "cli"
        apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
        apiModel = defaults.string(forKey: Keys.apiModel) ?? "claude-opus-4-8"
    }
}
