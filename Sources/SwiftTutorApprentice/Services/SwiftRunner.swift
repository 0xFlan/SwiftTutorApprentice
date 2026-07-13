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
    let workspaceWasSaved: Bool

    var didLaunch: Bool { launchError == nil }
    var succeeded: Bool { launchError == nil && exitCode == 0 }
}

/// Writes the learner's code to disk and runs it with the Swift interpreter.
///
/// This is `Sendable` (safe to use across threads) because it holds no
/// mutable state — every value it needs is passed in or is a static.
final class SwiftRunner: Sendable {

    private let workspaceURL: URL
    private let processRunner: CancellableProcessRunner

    /// Where we keep the file we run: ~/Developer/SwiftTutorApprentice/Workspace/
    static var defaultWorkspaceURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("SwiftTutorApprentice", isDirectory: true)
            .appendingPathComponent("Workspace", isDirectory: true)
    }

    init(
        workspaceURL: URL = SwiftRunner.defaultWorkspaceURL,
        processRunner: CancellableProcessRunner = CancellableProcessRunner()
    ) {
        self.workspaceURL = workspaceURL
        self.processRunner = processRunner
    }

    /// Run the given code and return the result.
    /// This is `async` so the UI stays responsive while Swift compiles.
    func run(code: String) async -> RunResult {
        let fileManager = FileManager.default

        // 1. Ensure the workspace folder exists.
        do {
            try fileManager.createDirectory(
                at: workspaceURL,
                withIntermediateDirectories: true
            )
        } catch {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not create the Workspace folder: \(error.localizedDescription)",
                workspaceWasSaved: false
            )
        }

        // 2. Write the code to main.swift.
        do {
            try code.write(
                to: workspaceURL.appendingPathComponent("main.swift", isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not save main.swift: \(error.localizedDescription)",
                workspaceWasSaved: false
            )
        }

        // 3. Launch a fixed executable and argument list in its own process
        //    group so cancelling this task terminates compiler descendants too.
        let result = await processRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["swift", "main.swift"],
            currentDirectoryURL: workspaceURL
        )
        if let launchError = result.launchError {
            return RunResult(
                stdout: "",
                stderr: "",
                exitCode: -1,
                launchError: "Could not start Swift: \(launchError)",
                workspaceWasSaved: true
            )
        }
        return RunResult(
            stdout: result.stdout,
            stderr: result.stderr,
            exitCode: result.exitCode,
            launchError: nil,
            workspaceWasSaved: true
        )
    }
}
