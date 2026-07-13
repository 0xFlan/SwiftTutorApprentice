import AppKit
import ObjectiveC.runtime
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class OfflineCoreContractTests: XCTestCase {
    func testBundledCourseHomeAndPilotPresentationsNeedNoNetworkOrAI() async throws {
        let swiftCourse = try XCTUnwrap(CourseCatalog.default[.swiftDevelopment])
        let pilotLessons = try [1, 2, 3].map { id in
            try XCTUnwrap(Curriculum.defaultLesson(id: id))
        }

        XCTAssertEqual(pilotLessons.count, 3)
        for lesson in pilotLessons {
            let presentation = try XCTUnwrap(lesson.presentation)
            XCTAssertEqual(presentation.provenance.source, .bundled)
            XCTAssertFalse(presentation.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(presentation.scenes.isEmpty)
            XCTAssertTrue(presentation.scenes.allSatisfy {
                !$0.narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.before.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !$0.after.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })

            let encoded = try JSONEncoder().encode(presentation)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: encoded) as? [String: Any]
            )
            XCTAssertFalse(
                containsForbiddenRemoteAsset(in: json),
                "\(presentation.id) contains a remote/media asset field"
            )
            let jsonText = try XCTUnwrap(String(data: encoded, encoding: .utf8)).lowercased()
            XCTAssertFalse(jsonText.contains("http://"))
            XCTAssertFalse(jsonText.contains("https://"))

            XCTAssertEqual(
                PresentationContentValidator.validate(
                    presentation,
                    lesson: lesson,
                    course: swiftCourse,
                    knownObjectivesBySet: [:]
                ),
                []
            )
        }

        let suite = "OfflineCoreContractTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(userDefaults: defaults)
        XCTAssertFalse(settings.aiEnabled)
        XCTAssertTrue(settings.apiKey.isEmpty)

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(suite, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = LessonStore(
            fileURL: root.appendingPathComponent("lessons.json"),
            defaults: Curriculum.defaultLessons
        )
        let progress = ProgressStore(
            fileURL: root.appendingPathComponent("progress.json"),
            now: Date.init,
            writeData: ProgressStore.atomicWrite
        )
        var aiRequests = 0
        let model = AppModel(
            store: store,
            progress: progress,
            settings: settings,
            contentRegistry: CourseContentRegistry(
                providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: store)]
            ),
            runCode: { _ in
                RunResult(
                    stdout: "",
                    stderr: "",
                    exitCode: 0,
                    launchError: nil,
                    workspaceWasSaved: true
                )
            },
            requestAI: { _ in
                aiRequests += 1
                return AIResult(text: "", errorMessage: "AI is not part of the offline core")
            }
        )

        let networkBoundary = try SerializedNetworkDenialBoundary.acquire()
        defer { networkBoundary.close() }
        let controlledSession = URLSession(configuration: .ephemeral)
        do {
            _ = try await controlledSession.data(
                from: URL(string: "https://offline-contract.invalid/probe")!
            )
            XCTFail("The controlled request unexpectedly escaped the denying boundary")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        controlledSession.finishTasksAndInvalidate()
        XCTAssertEqual(networkBoundary.requestCount, 1)
        networkBoundary.resetRequestCount()

        let hosted = NSHostingView(
            rootView: CourseHomeView(model: model)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        defer { window.orderOut(nil) }
        window.contentView = hosted
        window.orderFrontRegardless()
        hosted.layoutSubtreeIfNeeded()
        settle(hosted, for: 0.05)

        let cards = model.courseHomeCards()
        XCTAssertEqual(cards.map(\.id), CourseCatalog.default.definitions.map(\.id))
        XCTAssertEqual(CourseCatalog.default.definitions.count, 4)
        XCTAssertEqual(aiRequests, 0)
        XCTAssertEqual(networkBoundary.requestCount, 0)

        for definition in CourseCatalog.default.definitions {
            XCTAssertEqual(
                markers(named: "course-card-\(definition.id.rawValue)", in: hosted).count,
                1,
                "Rendered Course Home must contain every catalog card"
            )
            XCTAssertFalse(definition.certificationTargets.isEmpty)
            XCTAssertTrue(definition.certificationTargets.allSatisfy {
                $0.sourceURL.scheme == "https"
            })
        }
        XCTAssertEqual(
            networkBoundary.requestCount,
            0,
            "Certification URLs must remain inert references"
        )
        window.orderOut(nil)
        window.contentView = nil
        settle(hosted, for: 0.02)
        XCTAssertEqual(networkBoundary.requestCount, 0)
        networkBoundary.close()
    }

    func testSmokeStateScriptSafetyHarness() throws {
        try runSmokeStateSafetyHarness()
    }

    private func settle(_ view: NSView, for interval: TimeInterval) {
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
        view.layoutSubtreeIfNeeded()
    }

    private func runSmokeStateSafetyHarness() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let smokeScript = root.appendingPathComponent("Scripts/course-platform-smoke-state.sh")
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineCoreSmokeHarness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: testRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: testRoot) }

        let harness = #"""
        set -euo pipefail
        SCRIPT="$1"
        TEST_ROOT="$2"

        make_home() {
            mkdir -p "$1"
            (cd "$1" && pwd -P)
        }

        cleanup_case() {
            local name="$1" body="$2" expected="$3" remains="$4"
            local case_root="$TEST_ROOT/$name" temp_root="$TEST_ROOT/$name/temp" home session result
            mkdir -p "$temp_root"
            home="$(make_home "$case_root/home")"
            session="$(cd "$temp_root" && pwd -P)/SwiftTutorApprentice-smoke.${name}123"
            set +e
            TMPDIR="$temp_root/" HOME="$home" SESSION_UNDER_TEST="$session" bash -c \
                "source \"$SCRIPT\"; mkdir -p \"\$SESSION_UNDER_TEST\"; chmod 700 \"\$SESSION_UNDER_TEST\"; backup_transaction_begin \"\$SESSION_UNDER_TEST\"; $body"
            result=$?
            set -e
            [[ $result -eq $expected ]] || return 1
            if [[ "$remains" == yes ]]; then
                [[ -d "$session" ]] || return 1
            else
                [[ ! -e "$session" ]] || return 1
            fi
        }

        binding_case() {
            local name="$1" mutation="$2" fragment="$3"
            local case_root="$TEST_ROOT/$name" temp_root="$TEST_ROOT/$name/temp"
            local original_home changed_home session output result
            mkdir -p "$temp_root"
            original_home="$(make_home "$case_root/original-home")"
            changed_home="$(make_home "$case_root/changed-home")"
            session="$(cd "$temp_root" && pwd -P)/SwiftTutorApprentice-smoke.${name}123"
            set +e
            output="$(TMPDIR="$temp_root/" HOME="$original_home" SESSION_UNDER_TEST="$session" CHANGED_HOME="$changed_home" bash -c "
                source \"$SCRIPT\"
                mkdir -p \"\$SESSION_UNDER_TEST/snapshots\"
                chmod 700 \"\$SESSION_UNDER_TEST\"
                uuidgen > \"\$SESSION_UNDER_TEST/.session-marker\"
                chmod 600 \"\$SESSION_UNDER_TEST/.session-marker\"
                : > \"\$SESSION_UNDER_TEST/application-support.absent\"
                : > \"\$SESSION_UNDER_TEST/workspace.absent\"
                : > \"\$SESSION_UNDER_TEST/preferences.absent\"
                write_session_binding \"\$SESSION_UNDER_TEST\"
                $mutation
                validate_session \"\$SESSION_UNDER_TEST\"
                touch \"\$SESSION_UNDER_TEST/mutation-would-have-run\"
            " 2>&1)"
            result=$?
            set -e
            [[ $result -ne 0 && "$output" == *"$fragment"* ]] || return 1
            [[ ! -e "$session/mutation-would-have-run" ]] || return 1
        }

        snapshot_label_case() {
            local name="$1" label="$2"
            local case_root="$TEST_ROOT/$name" temp_root
            temp_root="$case_root/temp"
            local home session state_file expected_snapshot snapshot_count snapshot_path canonical_snapshot
            mkdir -p "$temp_root"
            home="$(make_home "$case_root/home")"
            session="$(cd "$temp_root" && pwd -P)/SwiftTutorApprentice-smoke.${name}123"
            state_file="$home/Library/Application Support/SwiftTutorApprentice/progress.json"
            mkdir -p "$session/snapshots" "$(dirname "$state_file")"
            chmod 700 "$session" "$session/snapshots"
            printf '{"progress":"synthetic"}\n' > "$state_file"
            expected_snapshot="$session/snapshots/$label.sha256"

            TMPDIR="$temp_root/" HOME="$home" SESSION_UNDER_TEST="$session" \
                STATE_FILE="$state_file" LABEL="$label" QUIT_MARKER="$case_root/quit-called" \
                bash -c '
                    source "$1"
                    quit_app() { : > "$QUIT_MARKER"; }
                    SESSION="$SESSION_UNDER_TEST"
                    snapshot "$LABEL" "$STATE_FILE"
                ' _ "$SCRIPT"

            [[ -f "$expected_snapshot" && ! -L "$expected_snapshot" ]] || return 1
            [[ "$(stat -f %Lp "$expected_snapshot")" == 600 ]] || return 1
            [[ -f "$case_root/quit-called" ]] || return 1
            snapshot_count="$(find "$case_root" -type f -name '*.sha256' | wc -l | tr -d ' ')"
            [[ "$snapshot_count" == 1 ]] || return 1
            snapshot_path="$(find "$case_root" -type f -name '*.sha256' -print)"
            canonical_snapshot="$(cd "$(dirname "$snapshot_path")" && pwd -P)/$(basename "$snapshot_path")"
            [[ "$canonical_snapshot" == "$expected_snapshot" ]] || return 1
        }

        rejected_snapshot_label_case() {
            local name="$1" label="$2"
            local case_root="$TEST_ROOT/$name" temp_root
            temp_root="$case_root/temp"
            local home session state_file output result
            mkdir -p "$temp_root"
            home="$(make_home "$case_root/home")"
            session="$(cd "$temp_root" && pwd -P)/SwiftTutorApprentice-smoke.${name}123"
            state_file="$home/Library/Application Support/SwiftTutorApprentice/progress.json"
            mkdir -p "$session/snapshots" "$(dirname "$state_file")"
            chmod 700 "$session" "$session/snapshots"
            printf '{"progress":"synthetic"}\n' > "$state_file"

            set +e
            output="$(TMPDIR="$temp_root/" HOME="$home" SESSION_UNDER_TEST="$session" \
                STATE_FILE="$state_file" LABEL="$label" QUIT_MARKER="$case_root/quit-called" \
                bash -c '
                    source "$1"
                    quit_app() { : > "$QUIT_MARKER"; }
                    SESSION="$SESSION_UNDER_TEST"
                    snapshot "$LABEL" "$STATE_FILE"
                ' _ "$SCRIPT" 2>&1)"
            result=$?
            set -e

            [[ $result -ne 0 && "$output" == *"snapshot label"* ]] || return 1
            [[ ! -e "$case_root/quit-called" ]] || return 1
            [[ -z "$(find "$case_root" -type f -name '*.sha256' -print)" ]] || return 1
            [[ "$(cat "$state_file")" == '{"progress":"synthetic"}' ]] || return 1
        }

        rejected_snapshot_directory_case() {
            local name="$1" operation="$2" directory_state="$3"
            local case_root="$TEST_ROOT/$name" temp_root
            temp_root="$case_root/temp"
            local home session state_file output result digest_count
            mkdir -p "$temp_root"
            home="$(make_home "$case_root/home")"
            session="$(cd "$temp_root" && pwd -P)/SwiftTutorApprentice-smoke.${name}123"
            state_file="$home/Library/Application Support/SwiftTutorApprentice/progress.json"
            mkdir -p "$session/snapshots" "$(dirname "$state_file")"
            chmod 700 "$session" "$session/snapshots"
            printf '{"progress":"synthetic"}\n' > "$state_file"
            if [[ "$operation" == assert ]]; then
                printf 'digest-sentinel\n' > "$session/snapshots/safe-label.sha256"
                chmod 600 "$session/snapshots/safe-label.sha256"
            fi
            if [[ "$directory_state" == symlink ]]; then
                mv "$session/snapshots" "$case_root/outside-snapshots"
                ln -s "$case_root/outside-snapshots" "$session/snapshots"
            else
                chmod "$directory_state" "$session/snapshots"
            fi

            set +e
            output="$(TMPDIR="$temp_root/" HOME="$home" SESSION_UNDER_TEST="$session" \
                STATE_FILE="$state_file" OPERATION="$operation" QUIT_MARKER="$case_root/quit-called" \
                bash -c '
                    source "$1"
                    quit_app() { : > "$QUIT_MARKER"; }
                    SESSION="$SESSION_UNDER_TEST"
                    if [[ "$OPERATION" == snapshot ]]; then
                        snapshot safe-label "$STATE_FILE"
                    else
                        assert_unchanged safe-label "$STATE_FILE"
                    fi
                ' _ "$SCRIPT" 2>&1)"
            result=$?
            set -e

            [[ $result -ne 0 && "$output" == *"snapshot directory"* ]] || {
                printf 'expected %s with %s snapshots directory to be rejected; status=%s output=%s\n' \
                    "$operation" "$directory_state" "$result" "$output" >&2
                return 1
            }
            [[ ! -e "$case_root/quit-called" ]] || return 1
            [[ "$(cat "$state_file")" == '{"progress":"synthetic"}' ]] || return 1
            digest_count="$(find "$case_root" -type f -name '*.sha256' | wc -l | tr -d ' ')"
            if [[ "$operation" == snapshot ]]; then
                [[ "$digest_count" == 0 ]] || return 1
            else
                [[ "$digest_count" == 1 ]] || return 1
                [[ "$(find "$case_root" -type f -name '*.sha256' -exec cat {} \;)" == digest-sentinel ]] \
                    || return 1
            fi
        }

        chmod_root="$TEST_ROOT/ChmodFirst"
        chmod_temp="$chmod_root/temp"
        chmod_home="$(make_home "$chmod_root/home")"
        mkdir -p "$chmod_temp"
        chmod_session="$(cd "$chmod_temp" && pwd -P)/SwiftTutorApprentice-smoke.ChmodFirst123"
        chmod_log="$chmod_root/order.log"
        set +e
        TMPDIR="$chmod_temp/" HOME="$chmod_home" SESSION_UNDER_TEST="$chmod_session" ORDER_LOG="$chmod_log" bash -c '
            source "$1"
            mktemp() { printf "mktemp\n" >> "$ORDER_LOG"; mkdir "$SESSION_UNDER_TEST"; printf "%s\n" "$SESSION_UNDER_TEST"; }
            chmod() { printf "chmod:%s\n" "$1" >> "$ORDER_LOG"; return 1; }
            create_backup_session
        ' _ "$SCRIPT"
        chmod_status=$?
        set -e
        [[ $chmod_status -ne 0 && ! -e "$chmod_session" ]] || exit 1
        [[ -f "$chmod_log" ]] || exit 1
        [[ "$(sed -n '1p' "$chmod_log")" == mktemp ]] || exit 1
        [[ "$(sed -n '2p' "$chmod_log")" == chmod:700 ]] || exit 1
        [[ "$(wc -l < "$chmod_log" | tr -d ' ')" == 2 ]] || exit 1

        cleanup_case NestedFailure 'nested_copy_failure() { false; }; nested_copy_failure; backup_transaction_complete' 1 no
        cleanup_case TermSignal 'kill -TERM $$; touch "$SESSION_UNDER_TEST/continued"' 143 no
        cleanup_case SuccessfulBackup 'backup_transaction_complete' 0 yes
        binding_case ChangedHome 'HOME="$CHANGED_HOME"; APP_DATA="$HOME/Library/Application Support/SwiftTutorApprentice"; WORKSPACE="$HOME/Developer/SwiftTutorApprentice/Workspace"' 'session HOME does not match current HOME'
        binding_case ChangedSurface 'APP_DATA="$HOME/Library/Application Support/AnotherApp"' 'session Application Support path does not match'
        binding_case SymlinkMetadata 'rm "$SESSION_UNDER_TEST/metadata/home"; ln -s /etc/hosts "$SESSION_UNDER_TEST/metadata/home"' 'session binding metadata is missing or unsafe'
        binding_case TamperedChecksum 'printf "%064d\n" 0 > "$SESSION_UNDER_TEST/metadata/binding.sha256"' 'session binding metadata checksum does not match'
        snapshot_label_case FutureProgress future-progress
        snapshot_label_case CorruptProgress corrupt-progress
        snapshot_label_case FutureLessons future-lessons
        rejected_snapshot_label_case Traversal ../escape
        rejected_snapshot_label_case Slash nested/name
        rejected_snapshot_label_case Whitespace 'future progress'
        rejected_snapshot_label_case DotOnly ...
        rejected_snapshot_label_case LeadingHyphen -future
        rejected_snapshot_label_case TrailingHyphen future-
        rejected_snapshot_label_case LeadingUnderscore _future
        rejected_snapshot_label_case TrailingUnderscore future_
        rejected_snapshot_label_case Glob '*'
        rejected_snapshot_label_case ShellSyntax 'future;touch-pwned'
        rejected_snapshot_label_case CommandSubstitution '$(touch pwned)'
        rejected_snapshot_label_case TooLong "$(printf 'a%.0s' {1..65})"
        rejected_snapshot_directory_case SnapshotMode755 snapshot 755
        rejected_snapshot_directory_case AssertMode755 assert 755
        rejected_snapshot_directory_case SnapshotMode777 snapshot 777
        rejected_snapshot_directory_case AssertMode777 assert 777
        rejected_snapshot_directory_case SnapshotSymlink snapshot symlink
        rejected_snapshot_directory_case AssertSymlink assert symlink
        """#

        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", harness, "_", smokeScript.path, testRoot.path]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertEqual(process.terminationStatus, 0, text)

        let restoreHarness = root.appendingPathComponent("Tests/Scripts/restore-transaction-tests.sh")
        let restoreProcess = Process()
        let restoreOutput = Pipe()
        restoreProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        restoreProcess.arguments = [restoreHarness.path, smokeScript.path]
        restoreProcess.environment = ProcessInfo.processInfo.environment.merging([
            "TMPDIR": testRoot.path + "/"
        ]) { _, override in override }
        restoreProcess.standardOutput = restoreOutput
        restoreProcess.standardError = restoreOutput
        try restoreProcess.run()
        restoreProcess.waitUntilExit()
        let restoreData = restoreOutput.fileHandleForReading.readDataToEndOfFile()
        let restoreText = String(decoding: restoreData, as: UTF8.self)
        XCTAssertEqual(restoreProcess.terminationStatus, 0, restoreText)
    }

    private func markers(named identifier: String, in view: NSView) -> [NSView] {
        var matches: [NSView] = []
        if view.identifier?.rawValue == identifier {
            matches.append(view)
        }
        for child in view.subviews {
            matches.append(contentsOf: markers(named: identifier, in: child))
        }
        return matches
    }

    private func containsForbiddenRemoteAsset(in value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            for (key, nestedValue) in dictionary {
                let normalizedKey = key.lowercased()
                if normalizedKey.contains("url")
                    || normalizedKey.contains("media")
                    || normalizedKey.contains("remote")
                    || normalizedKey.contains("asset")
                {
                    return true
                }
                if containsForbiddenRemoteAsset(in: nestedValue) {
                    return true
                }
            }
        } else if let array = value as? [Any] {
            return array.contains(where: containsForbiddenRemoteAsset)
        } else if let string = value as? String {
            let normalized = string.lowercased()
            return normalized.contains("http://") || normalized.contains("https://")
        }
        return false
    }
}

/// XCTest runs this contract serially, and this semaphore additionally owns
/// the complete process-global URLSessionConfiguration override lifecycle so
/// it cannot overlap another boundary in this test process.
private final class SerializedNetworkDenialBoundary {
    private static let ownership = DispatchSemaphore(value: 1)
    private var isClosed = false

    private init() {}

    static func acquire() throws -> SerializedNetworkDenialBoundary {
        ownership.wait()
        SerializedDenyingURLProtocol.begin()
        guard URLSessionConfiguration.installOfflineContractProtocolOverride() else {
            SerializedDenyingURLProtocol.end()
            ownership.signal()
            throw NetworkBoundaryError.registrationFailed
        }
        return SerializedNetworkDenialBoundary()
    }

    var requestCount: Int { SerializedDenyingURLProtocol.requestCount }

    func resetRequestCount() {
        SerializedDenyingURLProtocol.resetRequestCount()
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        URLSessionConfiguration.removeOfflineContractProtocolOverride()
        SerializedDenyingURLProtocol.end()
        Self.ownership.signal()
    }

    deinit { close() }
}

private enum NetworkBoundaryError: Error {
    case registrationFailed
}

private extension URLSessionConfiguration {
    static func installOfflineContractProtocolOverride() -> Bool {
        guard let original = class_getInstanceMethod(
            URLSessionConfiguration.self,
            #selector(getter: URLSessionConfiguration.protocolClasses)
        ), let replacement = class_getInstanceMethod(
            URLSessionConfiguration.self,
            #selector(URLSessionConfiguration.offlineContractProtocolClasses)
        ) else { return false }
        method_exchangeImplementations(original, replacement)
        return true
    }

    static func removeOfflineContractProtocolOverride() {
        _ = installOfflineContractProtocolOverride()
    }

    @objc func offlineContractProtocolClasses() -> [AnyClass]? {
        var classes = offlineContractProtocolClasses() ?? []
        if !classes.contains(where: { $0 == SerializedDenyingURLProtocol.self }) {
            classes.insert(SerializedDenyingURLProtocol.self, at: 0)
        }
        return classes
    }
}

private final class SerializedDenyingURLProtocol: URLProtocol {
    private static let stateLock = NSLock()
    private static var isActive = false
    private static var storedRequestCount = 0

    static var requestCount: Int {
        stateLock.withLock { storedRequestCount }
    }

    static func begin() {
        stateLock.withLock {
            precondition(!isActive)
            isActive = true
            storedRequestCount = 0
        }
    }

    static func resetRequestCount() {
        stateLock.withLock { storedRequestCount = 0 }
    }

    static func end() {
        stateLock.withLock {
            isActive = false
            storedRequestCount = 0
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        let active = stateLock.withLock { isActive }
        guard active, let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.stateLock.withLock { Self.storedRequestCount += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
