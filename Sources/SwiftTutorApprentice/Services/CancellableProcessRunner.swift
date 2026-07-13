import Darwin
import Foundation

struct CancellableProcessResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    let launchError: String?
}

struct POSIXProcessSystem: @unchecked Sendable {
    typealias FileActionsPointer = UnsafeMutablePointer<posix_spawn_file_actions_t?>
    typealias AttributesPointer = UnsafeMutablePointer<posix_spawnattr_t?>
    typealias ArgumentVector = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>

    var makePipe: (UnsafeMutablePointer<Int32>) -> Int32
    var closeDescriptor: (Int32) -> Void
    var fileActionsInit: (FileActionsPointer) -> Int32
    var fileActionsDestroy: (FileActionsPointer) -> Void
    var attributesInit: (AttributesPointer) -> Int32
    var attributesDestroy: (AttributesPointer) -> Void
    var addDuplicate: (FileActionsPointer, Int32, Int32) -> Int32
    var addClose: (FileActionsPointer, Int32) -> Int32
    var addChdir: (FileActionsPointer, String) -> Int32
    var setFlags: (AttributesPointer, Int16) -> Int32
    var setProcessGroup: (AttributesPointer, pid_t) -> Int32
    var duplicateArgument: (String) -> UnsafeMutablePointer<CChar>?
    var freeArgument: (UnsafeMutablePointer<CChar>) -> Void
    var spawn: (
        UnsafeMutablePointer<pid_t>,
        String,
        FileActionsPointer,
        AttributesPointer,
        ArgumentVector
    ) -> Int32

    static let live = POSIXProcessSystem(
        makePipe: { Darwin.pipe($0) },
        closeDescriptor: { _ = Darwin.close($0) },
        fileActionsInit: { posix_spawn_file_actions_init($0) },
        fileActionsDestroy: { _ = posix_spawn_file_actions_destroy($0) },
        attributesInit: { posix_spawnattr_init($0) },
        attributesDestroy: { _ = posix_spawnattr_destroy($0) },
        addDuplicate: { posix_spawn_file_actions_adddup2($0, $1, $2) },
        addClose: { posix_spawn_file_actions_addclose($0, $1) },
        addChdir: { posix_spawn_file_actions_addchdir_np($0, $1) },
        setFlags: { posix_spawnattr_setflags($0, $1) },
        setProcessGroup: { posix_spawnattr_setpgroup($0, $1) },
        duplicateArgument: { strdup($0) },
        freeArgument: { free($0) },
        spawn: { pid, executablePath, actions, attributes, arguments in
            executablePath.withCString {
                posix_spawn(pid, $0, actions, attributes, arguments, environ)
            }
        }
    )
}

/// Launches one fixed executable with a fixed argument array. Each child is a
/// process-group leader before exec, so cancellation also reaches descendants.
final class CancellableProcessRunner: Sendable {
    private static let workQueue = DispatchQueue(
        label: "SwiftTutorApprentice.process-runner",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let system: POSIXProcessSystem

    init(system: POSIXProcessSystem = .live) {
        self.system = system
    }

    func run(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL? = nil
    ) async -> CancellableProcessResult {
        let invocation = ProcessInvocation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                Self.workQueue.async {
                    continuation.resume(returning: Self.execute(
                        executableURL: executableURL,
                        arguments: arguments,
                        currentDirectoryURL: currentDirectoryURL,
                        invocation: invocation,
                        system: self.system
                    ))
                }
            }
        } onCancel: {
            invocation.cancel()
        }
    }

    private static func execute(
        executableURL: URL,
        arguments: [String],
        currentDirectoryURL: URL?,
        invocation: ProcessInvocation,
        system: POSIXProcessSystem
    ) -> CancellableProcessResult {
        var stdoutPipe = [Int32](repeating: -1, count: 2)
        var stderrPipe = [Int32](repeating: -1, count: 2)
        func closeOwnedDescriptor(_ descriptor: inout Int32) {
            guard descriptor >= 0 else { return }
            system.closeDescriptor(descriptor)
            descriptor = -1
        }
        defer {
            for index in stdoutPipe.indices {
                closeOwnedDescriptor(&stdoutPipe[index])
                closeOwnedDescriptor(&stderrPipe[index])
            }
        }

        guard system.makePipe(&stdoutPipe) == 0 else {
            return launchFailure("Could not create stdout pipe")
        }
        guard system.makePipe(&stderrPipe) == 0 else {
            return launchFailure("Could not create stderr pipe")
        }

        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        var actionsInitialized = false
        var attributesInitialized = false

        var setupCode = system.fileActionsInit(&actions)
        guard setupCode == 0 else {
            return setupFailure("initialize spawn file actions", code: setupCode)
        }
        actionsInitialized = true
        defer {
            if attributesInitialized { system.attributesDestroy(&attributes) }
            if actionsInitialized { system.fileActionsDestroy(&actions) }
        }

        setupCode = system.attributesInit(&attributes)
        guard setupCode == 0 else {
            return setupFailure("initialize spawn attributes", code: setupCode)
        }
        attributesInitialized = true

        let duplicateActions = [
            (stdoutPipe[1], STDOUT_FILENO, "redirect stdout"),
            (stderrPipe[1], STDERR_FILENO, "redirect stderr")
        ]
        for (source, destination, operation) in duplicateActions {
            setupCode = system.addDuplicate(&actions, source, destination)
            guard setupCode == 0 else {
                return setupFailure(operation, code: setupCode)
            }
        }
        for descriptor in [stdoutPipe[0], stderrPipe[0], stdoutPipe[1], stderrPipe[1]] {
            setupCode = system.addClose(&actions, descriptor)
            guard setupCode == 0 else {
                return setupFailure("close inherited pipe descriptor", code: setupCode)
            }
        }
        if let currentDirectoryURL {
            setupCode = system.addChdir(&actions, currentDirectoryURL.path)
            guard setupCode == 0 else {
                return setupFailure("set child working directory", code: setupCode)
            }
        }

        let flags = Int16(POSIX_SPAWN_SETPGROUP)
        setupCode = system.setFlags(&attributes, flags)
        guard setupCode == 0 else {
            return setupFailure("set spawn flags", code: setupCode)
        }
        setupCode = system.setProcessGroup(&attributes, 0)
        guard setupCode == 0 else {
            return setupFailure("set child process group", code: setupCode)
        }

        let argumentStrings = [executableURL.path] + arguments
        var cArguments: [UnsafeMutablePointer<CChar>?] = []
        defer {
            for case let argument? in cArguments {
                system.freeArgument(argument)
            }
        }
        for argumentString in argumentStrings {
            guard let argument = system.duplicateArgument(argumentString) else {
                return launchFailure("Could not allocate child process arguments")
            }
            cArguments.append(argument)
        }
        cArguments.append(nil)

        var pid: pid_t = 0
        let spawnCode = cArguments.withUnsafeMutableBufferPointer { argumentBuffer in
            system.spawn(
                &pid,
                executableURL.path,
                &actions,
                &attributes,
                argumentBuffer.baseAddress!
            )
        }

        closeOwnedDescriptor(&stdoutPipe[1])
        closeOwnedDescriptor(&stderrPipe[1])

        guard spawnCode == 0 else {
            return launchFailure(
                "Could not launch \(executableURL.path): \(String(cString: strerror(spawnCode)))"
            )
        }

        invocation.install(pid: pid)

        var stdoutData = Data()
        var stderrData = Data()
        guard setNonBlocking(stdoutPipe[0]), setNonBlocking(stderrPipe[0]) else {
            invocation.cancel()
            invocation.finishCancellationAndPrepareToReap(pid: pid)
            var ignoredStatus: Int32 = 0
            while waitpid(pid, &ignoredStatus, 0) == -1 && errno == EINTR {}
            return launchFailure("Could not configure nonblocking child output")
        }

        // Poll without reaping under the same lifecycle lock used by signals.
        // An ECHILD/error result therefore disables signals before cancellation
        // can act on a numeric identity the OS no longer proves is reserved.
        var exitObservation: ProcessExitObservation = .running
        while exitObservation == .running {
            drainAvailable(from: stdoutPipe[0], into: &stdoutData)
            drainAvailable(from: stderrPipe[0], into: &stderrData)
            exitObservation = invocation.observeExitWithoutReaping(pid: pid) {
                var exitInfo = siginfo_t()
                var result: Int32
                repeat {
                    result = waitid(
                        P_PID,
                        id_t(pid),
                        &exitInfo,
                        WEXITED | WNOWAIT | WNOHANG
                    )
                } while result == -1 && errno == EINTR
                return (
                    result: result,
                    hasExited: result == 0 && exitInfo.si_pid == pid,
                    error: result == 0 ? 0 : errno
                )
            }
            if exitObservation == .running {
                Thread.sleep(forTimeInterval: 0.005)
            }
        }

        guard exitObservation == .exited else {
            let observeError: Int32
            if case .failed(let error) = exitObservation {
                observeError = error
            } else {
                observeError = ECHILD
            }
            return launchFailure(
                "Could not observe \(executableURL.path) exit: \(String(cString: strerror(observeError)))"
            )
        }

        // The leader has completed every write it can make. One full Darwin
        // pipe snapshot includes every byte already queued at that point, but
        // bounds reads if an unrelated descendant keeps writing indefinitely.
        drainAvailable(from: stdoutPipe[0], into: &stdoutData, byteLimit: Int(BIG_PIPE_SIZE))
        drainAvailable(from: stderrPipe[0], into: &stderrData, byteLimit: Int(BIG_PIPE_SIZE))
        invocation.finishCancellationAndPrepareToReap(pid: pid)

        var waitStatus: Int32 = 0
        var waitResult: pid_t
        repeat {
            waitResult = waitpid(pid, &waitStatus, 0)
        } while waitResult == -1 && errno == EINTR

        guard waitResult == pid else {
            return launchFailure("Could not reap \(executableURL.path)")
        }
        return CancellableProcessResult(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: decodedExitCode(waitStatus),
            launchError: nil
        )
    }

    private static func decodedExitCode(_ status: Int32) -> Int32 {
        let signal = status & 0x7f
        if signal == 0 {
            return (status >> 8) & 0xff
        }
        return 128 + signal
    }

    private static func setNonBlocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags != -1 else { return false }
        return fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) != -1
    }

    private static func drainAvailable(
        from descriptor: Int32,
        into data: inout Data,
        byteLimit: Int = 262_144
    ) {
        var remaining = byteLimit
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while remaining > 0 {
            let requested = min(buffer.count, remaining)
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, requested)
            }
            if count > 0 {
                data.append(buffer, count: count)
                remaining -= count
            } else if count == -1 && errno == EINTR {
                continue
            } else {
                return
            }
        }
    }

    private static func setupFailure(_ operation: String, code: Int32) -> CancellableProcessResult {
        launchFailure("Could not \(operation): \(String(cString: strerror(code)))")
    }

    private static func launchFailure(_ message: String) -> CancellableProcessResult {
        CancellableProcessResult(
            stdout: "",
            stderr: "",
            exitCode: -1,
            launchError: message
        )
    }
}

enum ProcessExitObservation: Equatable {
    case running
    case exited
    case failed(Int32)
    case identityDisabled
}

final class ProcessInvocation: @unchecked Sendable {
    typealias SignalGroup = (pid_t, Int32) -> Void
    typealias ScheduleFallback = (@escaping () -> Void) -> Void

    private let lock = NSLock()
    private let signalGroup: SignalGroup
    private let scheduleFallback: ScheduleFallback
    private var pid: pid_t?
    private var cancellationRequested = false
    private var sentTermination = false
    private var fallbackCompleted = false
    private var fallbackFinished: DispatchSemaphore?

    init(
        signalGroup: @escaping SignalGroup = { group, signal in
            Darwin.kill(-group, signal)
        },
        scheduleFallback: @escaping ScheduleFallback = { action in
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + .milliseconds(500),
                execute: action
            )
        }
    ) {
        self.signalGroup = signalGroup
        self.scheduleFallback = scheduleFallback
    }

    func install(pid: pid_t) {
        lock.lock()
        self.pid = pid
        let fallback = beginTerminationIfNeededLocked()
        lock.unlock()
        schedule(fallback)
    }

    func cancel() {
        lock.lock()
        cancellationRequested = true
        let fallback = beginTerminationIfNeededLocked()
        lock.unlock()
        schedule(fallback)
    }

    /// Completes the cancellation escalation, then atomically disables every
    /// future signal before the caller reaps the reserved PID.
    func finishCancellationAndPrepareToReap(pid expectedPID: pid_t) {
        while true {
            lock.lock()
            guard pid == expectedPID else {
                lock.unlock()
                return
            }
            if cancellationRequested,
               let fallbackFinished,
               !fallbackCompleted
            {
                lock.unlock()
                fallbackFinished.wait()
                continue
            }
            pid = nil
            lock.unlock()
            return
        }
    }

    func observeExitWithoutReaping(
        pid expectedPID: pid_t,
        observe: () -> (result: Int32, hasExited: Bool, error: Int32)
    ) -> ProcessExitObservation {
        lock.lock()
        guard pid == expectedPID else {
            lock.unlock()
            return .identityDisabled
        }

        let observation = observe()
        if observation.result == 0 {
            lock.unlock()
            return observation.hasExited ? .exited : .running
        }

        let fallbackFinished = disableSignalsLocked(pid: expectedPID)
        lock.unlock()
        fallbackFinished?.signal()
        return .failed(observation.error)
    }

    private func disableSignalsLocked(pid expectedPID: pid_t) -> DispatchSemaphore? {
        guard pid == expectedPID else { return nil }
        pid = nil
        fallbackCompleted = true
        return fallbackFinished
    }

    private func beginTerminationIfNeededLocked() -> (pid_t, DispatchSemaphore)? {
        guard cancellationRequested,
              let pid,
              !sentTermination
        else { return nil }

        sentTermination = true
        let completion = DispatchSemaphore(value: 0)
        fallbackFinished = completion
        // The decision and syscall share the lifecycle lock. Once prepare to
        // reap clears `pid`, no signal can race into a reused process group.
        signalGroup(pid, SIGTERM)
        return (pid, completion)
    }

    private func schedule(_ fallback: (pid_t, DispatchSemaphore)?) {
        guard let (group, completion) = fallback else { return }
        scheduleFallback { [weak self] in
            self?.forceKillAndComplete(group: group, completion: completion)
        }
    }

    private func forceKillAndComplete(group: pid_t, completion: DispatchSemaphore) {
        lock.lock()
        guard !fallbackCompleted else {
            lock.unlock()
            return
        }
        if pid == group && sentTermination {
            signalGroup(group, SIGKILL)
        }
        fallbackCompleted = true
        lock.unlock()
        completion.signal()
    }
}
