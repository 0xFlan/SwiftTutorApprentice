import Darwin
import XCTest
@testable import SwiftTutorApprentice

final class CancellableProcessRunnerTests: XCTestCase {
    func testSwiftRunnerReportsWorkspacePersistenceSeparatelyFromExecution() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftRunnerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let savedWorkspace = root.appendingPathComponent("saved", isDirectory: true)
        let savedResult = await SwiftRunner(workspaceURL: savedWorkspace).run(code: "let =")
        XCTAssertTrue(savedResult.workspaceWasSaved)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: savedWorkspace.appendingPathComponent("main.swift").path
        ))
        XCTAssertFalse(savedResult.succeeded)

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blockedWorkspace = root.appendingPathComponent("blocked", isDirectory: false)
        try Data("not a directory".utf8).write(to: blockedWorkspace)
        let blockedResult = await SwiftRunner(workspaceURL: blockedWorkspace).run(code: "print(1)")
        XCTAssertFalse(blockedResult.workspaceWasSaved)
        XCTAssertFalse(blockedResult.didLaunch)
    }

    func testCancellationTerminatesChildProcess() async throws {
        let runner = CancellableProcessRunner()
        let started = Date()
        let task = Task {
            await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/sleep"),
                arguments: ["30"]
            )
        }
        try await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let result = await task.value

        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertNotEqual(result.exitCode, 0)
        XCTAssertNil(result.launchError)
    }

    func testCancellationKillsTermIgnoringDescendantThatKeepsPipesOpen() async throws {
        let leaderReadyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellableProcessRunner-leader-\(UUID().uuidString).ready")
        let readyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellableProcessRunner-child-\(UUID().uuidString).ready")
        defer {
            try? FileManager.default.removeItem(at: leaderReadyURL)
            try? FileManager.default.removeItem(at: readyURL)
        }

        let childScript = """
        import signal, sys, time
        signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGTERM})
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        open(sys.argv[1], 'w').write('ready')
        time.sleep(8)
        """
        let leaderScript = """
        import os, signal, subprocess, sys, time
        signal.pthread_sigmask(signal.SIG_UNBLOCK, {signal.SIGTERM})
        signal.signal(signal.SIGTERM, lambda *_: os._exit(143))
        subprocess.Popen(['/usr/bin/python3', '-c', sys.argv[3], sys.argv[2]])
        open(sys.argv[1], 'w').write('ready')
        time.sleep(30)
        """
        let runner = CancellableProcessRunner()
        let started = Date()
        let task = Task {
            await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: [
                    "-c", leaderScript,
                    leaderReadyURL.path,
                    readyURL.path,
                    childScript
                ]
            )
        }
        try await waitForFile(at: leaderReadyURL)
        try await waitForFile(at: readyURL)
        task.cancel()
        let result = await task.value

        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertEqual(result.exitCode, 143, "the leader must exit on TERM before fallback")
        XCTAssertNil(result.launchError)
    }

    func testCapturesBothOutputStreamsAndExitStatus() async {
        let runner = CancellableProcessRunner()
        let success = await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["out"]
        )
        XCTAssertEqual(success.stdout, "out")
        XCTAssertEqual(success.stderr, "")
        XCTAssertEqual(success.exitCode, 0)
        XCTAssertNil(success.launchError)

        let failure = await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
            arguments: ["%"]
        )
        XCTAssertEqual(failure.stdout, "")
        XCTAssertFalse(failure.stderr.isEmpty)
        XCTAssertEqual(failure.exitCode, 1)
        XCTAssertNil(failure.launchError)
    }

    func testLeaderExitDoesNotWaitForDescendantHoldingBothOutputPipes() async throws {
        let descendantPIDURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellableProcessRunner-descendant-\(UUID().uuidString).pid")
        let descendantPIDTempURL = URL(fileURLWithPath: descendantPIDURL.path + ".tmp")
        let leaderExitedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellableProcessRunner-leader-\(UUID().uuidString).exited")
        let leaderExitedTempURL = URL(fileURLWithPath: leaderExitedURL.path + ".tmp")
        var descendantPID: pid_t?
        defer {
            let cleanupPID = descendantPID
                ?? parseCompletePID(at: descendantPIDURL)
                ?? parseCompletePID(at: descendantPIDTempURL)
            if let cleanupPID {
                _ = Darwin.kill(cleanupPID, SIGKILL)
                XCTAssertTrue(
                    waitForProcessToDisappear(cleanupPID),
                    "descendant \(cleanupPID) survived test cleanup"
                )
            }
            try? FileManager.default.removeItem(at: descendantPIDURL)
            try? FileManager.default.removeItem(at: descendantPIDTempURL)
            try? FileManager.default.removeItem(at: leaderExitedURL)
            try? FileManager.default.removeItem(at: leaderExitedTempURL)
        }

        let descendantScript = """
        import os, sys, time
        temporary = sys.argv[1] + '.tmp'
        with open(temporary, 'w') as stream:
            stream.write(f'{os.getpid()}\\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, sys.argv[1])
        time.sleep(30)
        """
        let leaderScript = """
        import os, subprocess, sys
        subprocess.Popen(['/usr/bin/python3', '-c', sys.argv[3], sys.argv[1]])
        print('leader stdout', flush=True)
        print('leader stderr', file=sys.stderr, flush=True)
        temporary = sys.argv[2] + '.tmp'
        with open(temporary, 'w') as stream:
            stream.write(f'{os.getpid()}\\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, sys.argv[2])
        """
        let completed = expectation(description: "runner returns after its leader exits")
        let runner = CancellableProcessRunner()
        let task = Task {
            let result = await runner.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: [
                    "-c", leaderScript,
                    descendantPIDURL.path,
                    leaderExitedURL.path,
                    descendantScript
                ]
            )
            completed.fulfill()
            return result
        }

        descendantPID = try await waitForParseablePID(at: descendantPIDURL)
        let liveDescendantPID = try XCTUnwrap(descendantPID)
        let leaderPID = try await waitForParseablePID(at: leaderExitedURL)
        try await waitForProcessToExitOrBecomeZombie(leaderPID)
        XCTAssertEqual(Darwin.kill(liveDescendantPID, 0), 0, "descendant must still be alive")

        await fulfillment(of: [completed], timeout: 0.75)
        task.cancel() // Bounds the RED path; cancelling an already completed task is harmless.
        let result = await task.value
        XCTAssertEqual(result.stdout, "leader stdout\n")
        XCTAssertEqual(result.stderr, "leader stderr\n")
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.launchError)
    }

    func testPIDReadinessWaitsPastEmptyAndPartialFiles() async throws {
        let pidURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CancellableProcessRunner-pid-readiness-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: pidURL) }
        try Data().write(to: pidURL)

        let writer = Task {
            try await Task.sleep(nanoseconds: 40_000_000)
            try Data("12".utf8).write(to: pidURL)
            try await Task.sleep(nanoseconds: 40_000_000)
            try Data("4242\n".utf8).write(to: pidURL)
        }

        let pid = try await waitForParseablePID(at: pidURL)
        try await writer.value
        XCTAssertEqual(pid, 4_242)
    }

    func testLifecycleBarrierFinishesFallbackBeforeReapAndDisablesLaterSignals() {
        var signals: [(pid_t, Int32)] = []
        var scheduledFallback: (() -> Void)?
        let invocation = ProcessInvocation(
            signalGroup: { group, signal in signals.append((group, signal)) },
            scheduleFallback: { scheduledFallback = $0 }
        )
        invocation.install(pid: 4_242)
        invocation.cancel()
        XCTAssertEqual(signals.map(\.1), [SIGTERM])

        let finishReturned = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            invocation.finishCancellationAndPrepareToReap(pid: 4_242)
            finishReturned.signal()
        }
        XCTAssertEqual(finishReturned.wait(timeout: .now() + .milliseconds(50)), .timedOut)

        scheduledFallback?()
        XCTAssertEqual(finishReturned.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(signals.map(\.1), [SIGTERM, SIGKILL])

        invocation.cancel()
        scheduledFallback?()
        XCTAssertEqual(signals.map(\.1), [SIGTERM, SIGKILL])
    }

    func testAlreadyReapedIdentityDisablesCancellationAndPendingFallbackSignals() {
        var untouchedSignals: [Int32] = []
        var untouchedFallback: (() -> Void)?
        let untouched = ProcessInvocation(
            signalGroup: { _, signal in untouchedSignals.append(signal) },
            scheduleFallback: { untouchedFallback = $0 }
        )
        untouched.install(pid: 7_001)
        XCTAssertEqual(
            untouched.observeExitWithoutReaping(pid: 7_001) {
                (result: -1, hasExited: false, error: ECHILD)
            },
            .failed(ECHILD)
        )
        untouched.cancel()
        untouchedFallback?()
        XCTAssertTrue(untouchedSignals.isEmpty)

        var pendingSignals: [Int32] = []
        var pendingFallback: (() -> Void)?
        let pending = ProcessInvocation(
            signalGroup: { _, signal in pendingSignals.append(signal) },
            scheduleFallback: { pendingFallback = $0 }
        )
        pending.install(pid: 7_002)
        pending.cancel()
        XCTAssertEqual(pendingSignals, [SIGTERM])

        XCTAssertEqual(
            pending.observeExitWithoutReaping(pid: 7_002) {
                (result: -1, hasExited: false, error: ECHILD)
            },
            .failed(ECHILD)
        )
        pendingFallback?()
        pending.cancel()
        XCTAssertEqual(pendingSignals, [SIGTERM])
    }

    func testEveryPOSIXSetupFailureCleansOnlyInitializedResourcesAndNeverSpawns() async {
        let failures: [FakePOSIXFailure] = [
            .fileActionsInit,
            .attributesInit,
            .action(0), .action(1), .action(2), .action(3),
            .action(4), .action(5), .action(6),
            .setFlags,
            .setProcessGroup,
            .argument(0), .argument(1), .argument(2)
        ]

        for failure in failures {
            let recorder = FakePOSIXRecorder(failure: failure)
            let runner = CancellableProcessRunner(system: recorder.makeSystem())
            let result = await runner.run(
                executableURL: URL(fileURLWithPath: "/bin/echo"),
                arguments: ["one", "two"],
                currentDirectoryURL: FileManager.default.temporaryDirectory
            )

            XCTAssertNotNil(result.launchError, "\(failure)")
            XCTAssertEqual(recorder.spawnCount, 0, "\(failure)")
            XCTAssertEqual(Set(recorder.closedDescriptors), Set([101, 102, 103, 104]), "\(failure)")
            XCTAssertEqual(recorder.allocatedArgumentCount, recorder.freedArgumentCount, "\(failure)")
            switch failure {
            case .fileActionsInit:
                XCTAssertEqual(recorder.fileActionsDestroyCount, 0)
                XCTAssertEqual(recorder.attributesDestroyCount, 0)
            case .attributesInit:
                XCTAssertEqual(recorder.fileActionsDestroyCount, 1)
                XCTAssertEqual(recorder.attributesDestroyCount, 0)
            default:
                XCTAssertEqual(recorder.fileActionsDestroyCount, 1)
                XCTAssertEqual(recorder.attributesDestroyCount, 1)
            }
        }
    }

    private func waitForFile(at url: URL) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !FileManager.default.fileExists(atPath: url.path), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    private func waitForParseablePID(at url: URL) async throws -> pid_t {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let pid = parseCompletePID(at: url) {
                return pid
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw PIDReadinessError.timedOut
    }

    private func parseCompletePID(at url: URL) -> pid_t? {
        guard let value = try? String(contentsOf: url, encoding: .utf8),
              value.hasSuffix("\n"),
              let pid = pid_t(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              pid > 0
        else { return nil }
        return pid
    }

    private func waitForProcessToDisappear(_ pid: pid_t) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                return true
            }
            if Darwin.kill(pid, 0) == -1 && errno == ESRCH {
                return true
            }
            usleep(10_000)
        }
        return Darwin.kill(pid, 0) == -1 && errno == ESRCH
    }

    private func waitForProcessToExitOrBecomeZombie(_ pid: pid_t) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !processHasExitedOrBecomeZombie(pid), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(processHasExitedOrBecomeZombie(pid), "leader \(pid) did not exit")
    }

    private func processHasExitedOrBecomeZombie(_ pid: pid_t) -> Bool {
        if Darwin.kill(pid, 0) == -1 && errno == ESRCH {
            return true
        }
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "state=", "-p", String(pid)]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let state = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return state.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Z")
        } catch {
            return false
        }
    }
}

private enum PIDReadinessError: Error {
    case timedOut
}

private enum FakePOSIXFailure: CustomStringConvertible {
    case fileActionsInit
    case attributesInit
    case action(Int)
    case setFlags
    case setProcessGroup
    case argument(Int)

    var description: String {
        switch self {
        case .fileActionsInit: return "fileActionsInit"
        case .attributesInit: return "attributesInit"
        case .action(let index): return "action(\(index))"
        case .setFlags: return "setFlags"
        case .setProcessGroup: return "setProcessGroup"
        case .argument(let index): return "argument(\(index))"
        }
    }
}

private final class FakePOSIXRecorder: @unchecked Sendable {
    let failure: FakePOSIXFailure
    var nextDescriptor: Int32 = 101
    var actionIndex = 0
    var argumentIndex = 0
    var closedDescriptors: [Int32] = []
    var allocatedArgumentCount = 0
    var freedArgumentCount = 0
    var fileActionsDestroyCount = 0
    var attributesDestroyCount = 0
    var spawnCount = 0

    init(failure: FakePOSIXFailure) {
        self.failure = failure
    }

    func makeSystem() -> POSIXProcessSystem {
        var system = POSIXProcessSystem.live
        system.makePipe = { descriptors in
            descriptors[0] = self.nextDescriptor
            descriptors[1] = self.nextDescriptor + 1
            self.nextDescriptor += 2
            return 0
        }
        system.closeDescriptor = { self.closedDescriptors.append($0) }
        system.fileActionsInit = { _ in
            if case .fileActionsInit = self.failure { return EINVAL }
            return 0
        }
        system.fileActionsDestroy = { _ in
            self.fileActionsDestroyCount += 1
        }
        system.attributesInit = { _ in
            if case .attributesInit = self.failure { return EINVAL }
            return 0
        }
        system.attributesDestroy = { _ in
            self.attributesDestroyCount += 1
        }
        let action: (UnsafeMutablePointer<posix_spawn_file_actions_t?>) -> Int32 = { _ in
            defer { self.actionIndex += 1 }
            if case .action(self.actionIndex) = self.failure { return EINVAL }
            return 0
        }
        system.addDuplicate = { actions, _, _ in action(actions) }
        system.addClose = { actions, _ in action(actions) }
        system.addChdir = { actions, _ in action(actions) }
        system.setFlags = { _, _ in
            if case .setFlags = self.failure { return EINVAL }
            return 0
        }
        system.setProcessGroup = { _, _ in
            if case .setProcessGroup = self.failure { return EINVAL }
            return 0
        }
        system.duplicateArgument = { value in
            defer { self.argumentIndex += 1 }
            if case .argument(self.argumentIndex) = self.failure { return nil }
            self.allocatedArgumentCount += 1
            return strdup(value)
        }
        system.freeArgument = { pointer in
            self.freedArgumentCount += 1
            free(pointer)
        }
        system.spawn = { _, _, _, _, _ in
            self.spawnCount += 1
            return EINVAL
        }
        return system
    }
}
