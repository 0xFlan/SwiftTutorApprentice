// SwiftRunner.swift
// ------------------------------------------------------------
// Runs the learner's Swift code locally and captures the result.
//
// How it works:
//   1. Make sure a Workspace folder exists on disk.
//   2. Write the editor's code to Workspace/main.swift.
//   3. Run:  swift main.swift   (using the Swift interpreter)
//   4. Capture standard output (stdout), standard error (stderr),
//      and the process's exit code.
//
// SAFETY NOTE:
// We never run an arbitrary shell string. We launch the `swift`
// program directly with a fixed, controlled list of arguments
// (["swift", "main.swift"]). The only thing that changes is the
// contents of the main.swift file the learner wrote.
//
// TODO: Add SourceKit-LSP diagnostics for richer error feedback.
// ------------------------------------------------------------

import Foundation

/// The result of running the learner's program.
struct RunResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    /// Set only if the process could not even be launched
    /// (for example, if `swift` could not be found).
    let launchError: String?

    var didLaunch: Bool { launchError == nil }
    var succeeded: Bool { launchError == nil && exitCode == 0 }
}

/// Writes the learner's code to disk and runs it with the Swift interpreter.
///
/// This is `Sendable` (safe to use across threads) because it holds no
/// mutable state — every value it needs is passed in or is a static.
final class SwiftRunner: Sendable {

    /// Where we keep the file we run: ~/Developer/SwiftTutorApprentice/Workspace/
    static var workspaceURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
            .appendingPathComponent("Workspace", isDirectory: true)
    }

    static var mainSwiftURL: URL {
        workspaceURL.appendingPathComponent("main.swift", isDirectory: false)
    }

    /// Run the given code and return the result.
    /// This is `async` so the UI stays responsive while Swift compiles.
    func run(code: String) async -> RunResult {
        await withCheckedContinuation { continuation in
            // Do the blocking file + process work off the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.runSynchronously(code: code)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - The actual (blocking) work

    private func runSynchronously(code: String) -> RunResult {
        let fileManager = FileManager.default

        // 1. Ensure the workspace folder exists.
        do {
            try fileManager.createDirectory(
                at: Self.workspaceURL,
                withIntermediateDirectories: true
            )
        } catch {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not create the Workspace folder: \(error.localizedDescription)"
            )
        }

        // 2. Write the code to main.swift.
        do {
            try code.write(to: Self.mainSwiftURL, atomically: true, encoding: .utf8)
        } catch {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not save main.swift: \(error.localizedDescription)"
            )
        }

        // 3. Set up the process: /usr/bin/env swift main.swift
        //    Using /usr/bin/env lets the system find `swift` on the PATH,
        //    which works whether the app was launched from Terminal or Finder.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", "main.swift"]
        process.currentDirectoryURL = Self.workspaceURL

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        // 4. Launch it.
        do {
            try process.run()
        } catch {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not start Swift: \(error.localizedDescription)"
            )
        }

        // Read both pipes on separate threads while the process runs.
        // Reading concurrently avoids a deadlock that can happen if one
        // stream fills its buffer while we're blocked reading the other.
        var outData = Data()
        var errData = Data()
        let ioGroup = DispatchGroup()
        let ioQueue = DispatchQueue(label: "SwiftRunner.io", attributes: .concurrent)

        ioGroup.enter()
        ioQueue.async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }
        ioGroup.enter()
        ioQueue.async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }

        process.waitUntilExit()
        ioGroup.wait()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return RunResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus,
            launchError: nil
        )
    }
}
