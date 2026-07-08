// AICoach.swift
// ------------------------------------------------------------
// The OPTIONAL AI coach. It's off by default; the rule-based
// LiveCoach is always the primary experience. When the learner
// turns AI on and asks for help, this runs a local command-line
// tool (their `claude` CLI by default) and shows the reply.
//
// It works exactly like SwiftRunner: launch a program with a
// controlled argument list via Process — never an arbitrary shell
// string. Here the program is the AI CLI, invoked in its
// non-interactive "print" mode:  claude -p "<prompt>"
//
// Because a GUI app launched from Finder gets a minimal PATH, we
// resolve the tool's real location ourselves (checking ~/.local/bin,
// Homebrew, etc.) instead of relying on PATH.
//
// TODO: Add an API-key based provider as an alternative to the CLI.
// TODO: Add a "review my whole project" action.
// ------------------------------------------------------------

import Foundation

struct AIResult {
    let text: String
    /// Non-nil if we couldn't get a useful reply.
    let errorMessage: String?
}

/// Runs a local AI CLI on demand. `Sendable` because it holds no
/// mutable state — safe to use from a background thread.
final class AICoach: Sendable {

    /// Ask the AI coach about the learner's current code, in the context
    /// of the current lesson. `command` is the CLI to run (e.g. "claude").
    func explain(code: String, lesson: Lesson, command: String) async -> AIResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: self.run(code: code, lesson: lesson, command: command))
            }
        }
    }

    // MARK: - Private

    private func run(code: String, lesson: Lesson, command: String) -> AIResult {
        guard let executable = resolveExecutable(command) else {
            return AIResult(
                text: "",
                errorMessage: """
                Couldn't find the '\(command)' command. Make sure it's installed \
                and, in Settings, enter its name or full path (for example \
                /Users/you/.local/bin/claude).
                """
            )
        }

        let prompt = buildPrompt(code: code, lesson: lesson)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-p", prompt]
        // Run from a neutral directory so the CLI doesn't pick up unrelated
        // project context from wherever the app happens to be launched.
        process.currentDirectoryURL = FileManager.default.temporaryDirectory

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return AIResult(text: "", errorMessage: "Couldn't start '\(command)': \(error.localizedDescription)")
        }

        // Read both streams concurrently to avoid pipe deadlock.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "AICoach.io", attributes: .concurrent)
        group.enter(); queue.async { outData = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); queue.async { errData = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        process.waitUntilExit()
        group.wait()

        let stdout = (String(data: outData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let stderr = (String(data: errData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus != 0 || stdout.isEmpty {
            let detail = stderr.isEmpty ? "The tool returned no output (exit code \(process.terminationStatus))." : stderr
            return AIResult(
                text: "",
                errorMessage: "The AI tool didn't return a usable answer.\n\n\(detail)"
            )
        }

        return AIResult(text: stdout, errorMessage: nil)
    }

    /// Build a focused, beginner-friendly prompt. We ask the tool NOT to
    /// just hand over the solution — the app is about understanding.
    private func buildPrompt(code: String, lesson: Lesson) -> String {
        """
        You are a patient Swift tutor for an absolute beginner. Be encouraging \
        and concise (under 150 words). Do NOT rewrite the full solution for them; \
        guide them to understand it.

        Current lesson: "\(lesson.title)"
        Lesson goal: \(lesson.goal)
        Expected output: \(lesson.expectedOutput)

        The learner typed this Swift code:
        ---
        \(code.isEmpty ? "(nothing yet)" : code)
        ---

        In plain language: explain what this code does, point out any mistakes and \
        why they matter, and give one small hint for the next step. Do not use \
        tools or read files; just answer directly.
        """
    }

    /// Find the tool's executable. Accepts an absolute path, or a bare name
    /// we look for in common install locations (plus whatever PATH has).
    private func resolveExecutable(_ command: String) -> String? {
        let fm = FileManager.default

        if command.hasPrefix("/") {
            return fm.isExecutableFile(atPath: command) ? command : nil
        }

        let home = fm.homeDirectoryForCurrentUser.path
        var candidateDirs = [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
        ]
        // Also include anything on the current PATH, if present.
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidateDirs.append(contentsOf: path.split(separator: ":").map(String.init))
        }

        for dir in candidateDirs {
            let full = (dir as NSString).appendingPathComponent(command)
            if fm.isExecutableFile(atPath: full) {
                return full
            }
        }
        return nil
    }
}
