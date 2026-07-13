import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class OnboardingAndErrorViewTests: XCTestCase {
    func testWelcomeOrientsANewBeginnerTruthfully() throws {
        var startCalls = 0
        let rendered = host(
            WelcomeView(onStart: { startCalls += 1 }),
            size: NSSize(width: 680, height: 520)
        )

        let snapshot = try XCTUnwrap(
            marker(named: "welcome-copy-snapshot", in: rendered)
                as? WelcomeRuntimeSnapshotView
        )
        let copy = snapshot.copyText.lowercased()
        XCTAssertTrue(copy.contains("no experience"))
        XCTAssertTrue(copy.contains("course home"))
        XCTAssertTrue(copy.contains("watch → recall → modify → practice/run"))
        XCTAssertTrue(copy.contains("offline"))
        XCTAssertTrue(copy.contains("locally"))
        XCTAssertTrue(copy.contains("private"))
        XCTAssertTrue(copy.contains("explore courses"))
        XCTAssertFalse(copy.contains("certification"))
        XCTAssertFalse(copy.contains("job"))

        let sheet = try frame(named: "welcome-sheet", in: rendered)
        let actionView = try XCTUnwrap(marker(named: "welcome-action", in: rendered))
        let action = actionView.convert(actionView.bounds, to: rendered)
        let stepsProbe = try XCTUnwrap(
            marker(named: "welcome-steps-probe", in: rendered)
                as? WelcomeStepsRuntimeProbeView
        )
        let stepsScroll = try XCTUnwrap(stepsProbe.enclosingScrollView)
        let internalScrollViews = descendants(of: NSScrollView.self, in: rendered)
        XCTAssertLessThanOrEqual(sheet.height, 500)
        XCTAssertTrue(rendered.bounds.insetBy(dx: -1, dy: -1).contains(sheet))
        XCTAssertTrue(sheet.insetBy(dx: -1, dy: -1).contains(action))
        XCTAssertGreaterThan(action.width, 0)
        XCTAssertGreaterThan(action.height, 0)
        let scrollFrame = stepsScroll.convert(stepsScroll.bounds, to: rendered)
        XCTAssertGreaterThan(scrollFrame.height, 0)
        XCTAssertLessThan(scrollFrame.height, sheet.height)
        XCTAssertEqual(internalScrollViews.count, 1)
        XCTAssertNil(actionView.enclosingScrollView)

        let actionMarker = try XCTUnwrap(
            marker(named: "welcome-action-command", in: rendered)
                as? RuntimeNavigationActionView
        )
        actionMarker.invoke()
        XCTAssertEqual(startCalls, 1)
    }

    func testLocalPersistenceErrorsAreRecoverableAndSpecific() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        try assertFutureProgressIsReadOnly(in: root)
        try assertCorruptProgressIsReadOnly(in: root)
        try assertFailedSaveCanRetry(in: root)
        try assertUnsupportedLessonContentIsReadOnly(in: root)
    }

    func testSidebarRevealActionsUseTheInjectedExactStoreURLs() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let progressURL = root.appendingPathComponent("future-progress.json")
        try Data(#"{ "version":4,"payload":{"future":true} }"#.utf8)
            .write(to: progressURL)
        let progress = ProgressStore(fileURL: progressURL, now: Date.init)

        let fixture = try XCTUnwrap(
            Bundle.module.url(
                forResource: "future-presentation-lessons",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let lessonsURL = root.appendingPathComponent("future-lessons.json")
        try Data(contentsOf: fixture).write(to: lessonsURL)
        let store = LessonStore(fileURL: lessonsURL, defaults: Curriculum.defaultLessons)
        let suite = "OnboardingAndErrorViewTests-sidebar-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = AppSettings(userDefaults: defaults)
        let model = AppModel(
            store: store,
            progress: progress,
            settings: settings,
            contentRegistry: CourseContentRegistry(
                providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: store)]
            )
        )
        var revealed: [URL] = []
        let sidebar = LessonListSidebar(
            model: model,
            store: store,
            progress: progress,
            scrollCoordinator: LessonScrollCoordinator(),
            onManageLessons: {},
            onOpenSettings: {},
            revealFile: { revealed.append($0) }
        )
        let rendered = host(sidebar, size: NSSize(width: 300, height: 520))
        let progressAction = try XCTUnwrap(
            marker(named: "reveal-progress-file-sidebar", in: rendered)
                as? RuntimeNavigationActionView
        )
        let lessonAction = try XCTUnwrap(
            marker(named: "reveal-lessons-file-sidebar", in: rendered)
                as? RuntimeNavigationActionView
        )
        progressAction.invoke()
        lessonAction.invoke()
        XCTAssertEqual(revealed, [progressURL, lessonsURL])

        let footer = try frame(named: "course-sidebar-footer", in: rendered)
        XCTAssertGreaterThan(footer.width, 0)
        XCTAssertLessThanOrEqual(footer.height, 44)
    }

    private func assertFutureProgressIsReadOnly(in root: URL) throws {
        let progressURL = root.appendingPathComponent("future-progress.json")
        let original = Data(#"{ "version":4,"payload":{"future":true} }"#.utf8)
        try original.write(to: progressURL)
        let progress = ProgressStore(fileURL: progressURL, now: Date.init)
        var revealed: [URL] = []
        let content = try XCTUnwrap(PersistenceBannerContent(progress: progress))
        let rendered = host(
            LocalPersistenceBanner(
                content: content,
                retry: nil,
                revealFile: { revealed.append($0) }
            ),
            size: NSSize(width: 680, height: 180)
        )
        XCTAssertEqual(progress.persistenceURL, progressURL)
        let banner = try persistenceBanner("progress-unsupported", in: rendered)
        XCTAssertEqual(banner.titleText, "Progress is read-only")
        XCTAssertTrue(banner.detailText.contains("newer app version"))
        XCTAssertTrue(banner.detailText.contains("exact bytes"))
        XCTAssertTrue(banner.detailText.contains("still study lessons and run code"))
        XCTAssertNil(banner.retryCommand)
        XCTAssertEqual(banner.fileURL, progressURL)
        banner.revealCommand.invoke()
        XCTAssertEqual(revealed, [progressURL])
        XCTAssertEqual(try Data(contentsOf: progressURL), original)
        XCTAssertFalse(Curriculum.defaultLessons.isEmpty)
    }

    private func assertCorruptProgressIsReadOnly(in root: URL) throws {
        let progressURL = root.appendingPathComponent("corrupt-progress.json")
        let original = Data(#"{ "version":3,"courses":"not-an-object" }"#.utf8)
        try original.write(to: progressURL)
        let progress = ProgressStore(fileURL: progressURL, now: Date.init)
        var revealed: [URL] = []
        let content = try XCTUnwrap(PersistenceBannerContent(progress: progress))
        let rendered = host(
            LocalPersistenceBanner(
                content: content,
                retry: nil,
                revealFile: { revealed.append($0) }
            ),
            size: NSSize(width: 680, height: 180)
        )
        let banner = try persistenceBanner("progress-corrupt", in: rendered)
        XCTAssertEqual(banner.titleText, "Progress file couldn't be safely opened")
        XCTAssertTrue(banner.detailText.contains("damaged or invalid"))
        XCTAssertTrue(banner.detailText.contains("read-only"))
        XCTAssertTrue(banner.detailText.contains("exact bytes"))
        XCTAssertNil(banner.retryCommand)
        banner.revealCommand.invoke()
        XCTAssertEqual(revealed, [progressURL])
        XCTAssertEqual(try Data(contentsOf: progressURL), original)
    }

    private func assertFailedSaveCanRetry(in root: URL) throws {
        final class Writer {
            var shouldFail = true
            func write(_ data: Data, to url: URL) throws {
                if shouldFail { throw CocoaError(.fileWriteUnknown) }
                try data.write(to: url, options: .atomic)
            }
        }

        let writer = Writer()
        let progressURL = root.appendingPathComponent("retry-progress.json")
        let progress = ProgressStore(
            fileURL: progressURL,
            now: Date.init,
            writeData: writer.write
        )
        progress.markComplete(.swift(1))
        XCTAssertNotNil(progress.saveError)

        var revealed: [URL] = []
        let content = try XCTUnwrap(PersistenceBannerContent(progress: progress))
        let rendered = host(
            LocalPersistenceBanner(
                content: content,
                retry: progress.retrySave,
                revealFile: { revealed.append($0) }
            ),
            size: NSSize(width: 680, height: 180)
        )
        let banner = try persistenceBanner("progress-save-error", in: rendered)
        XCTAssertEqual(banner.titleText, "Progress hasn't been saved")
        XCTAssertTrue(banner.detailText.contains("still in memory"))
        XCTAssertEqual(banner.fileURL, progressURL)
        banner.revealCommand.invoke()
        XCTAssertEqual(revealed, [progressURL])

        writer.shouldFail = false
        try XCTUnwrap(banner.retryCommand).invoke()
        XCTAssertNil(progress.saveError)
        XCTAssertTrue(progress.isComplete(.swift(1)))
        XCTAssertTrue(FileManager.default.fileExists(atPath: progressURL.path))
    }

    private func assertUnsupportedLessonContentIsReadOnly(in root: URL) throws {
        let fixture = try XCTUnwrap(
            Bundle.module.url(
                forResource: "future-presentation-lessons",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let original = try Data(contentsOf: fixture)
        let workspaceRoot = root.appendingPathComponent("future-lessons-workspace")
        try FileManager.default.createDirectory(
            at: workspaceRoot,
            withIntermediateDirectories: true
        )
        let lessonsURL = workspaceRoot.appendingPathComponent("lessons.json")
        try original.write(to: lessonsURL)
        let store = LessonStore(fileURL: lessonsURL, defaults: Curriculum.defaultLessons)
        var revealed: [URL] = []
        let content = try XCTUnwrap(PersistenceBannerContent(lessonStore: store))
        let rendered = host(
            LocalPersistenceBanner(
                content: content,
                retry: nil,
                revealFile: { revealed.append($0) }
            ),
            size: NSSize(width: 680, height: 180)
        )
        XCTAssertEqual(store.persistenceURL, lessonsURL)
        let banner = try persistenceBanner("lesson-content-read-only", in: rendered)
        XCTAssertEqual(banner.titleText, "Lesson content is read-only")
        XCTAssertTrue(banner.detailText.contains("newer or unsupported lesson content"))
        XCTAssertTrue(banner.detailText.contains("exact bytes"))
        XCTAssertTrue(banner.detailText.contains("still study available lessons and run code"))
        XCTAssertNil(banner.retryCommand)
        XCTAssertEqual(banner.fileURL, lessonsURL)
        banner.revealCommand.invoke()
        XCTAssertEqual(revealed, [lessonsURL])
        XCTAssertEqual(try Data(contentsOf: lessonsURL), original)
        XCTAssertFalse(store.lessons.isEmpty)
    }

    private func persistenceBanner<Content: View>(
        _ identifier: String,
        in host: NSHostingView<Content>
    ) throws -> PersistenceBannerRuntimeView {
        try XCTUnwrap(marker(named: identifier, in: host) as? PersistenceBannerRuntimeView)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OnboardingAndErrorViewTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func host<Content: View>(
        _ content: Content,
        size: NSSize
    ) -> NSHostingView<Content> {
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(origin: .zero, size: size)
        refresh(host)
        return host
    }

    private func refresh(_ view: NSView) {
        for _ in 0..<3 {
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
        }
        view.layoutSubtreeIfNeeded()
    }

    private func markers(named identifier: String, in view: NSView) -> [NSView] {
        var matches: [NSView] = []
        if view.identifier?.rawValue == identifier { matches.append(view) }
        for child in view.subviews {
            matches.append(contentsOf: markers(named: identifier, in: child))
        }
        return matches
    }

    private func marker(named identifier: String, in view: NSView) -> NSView? {
        let matches = markers(named: identifier, in: view)
        XCTAssertEqual(matches.count, 1, "Expected one runtime marker named \(identifier)")
        return matches.first
    }

    private func descendants<ViewType: NSView>(
        of type: ViewType.Type,
        in view: NSView
    ) -> [ViewType] {
        var matches = view.subviews.compactMap { $0 as? ViewType }
        for child in view.subviews {
            matches.append(contentsOf: descendants(of: type, in: child))
        }
        return matches
    }

    private func frame<Content: View>(
        named identifier: String,
        in host: NSHostingView<Content>
    ) throws -> NSRect {
        let found = try XCTUnwrap(marker(named: identifier, in: host))
        return found.convert(found.bounds, to: host)
    }
}
