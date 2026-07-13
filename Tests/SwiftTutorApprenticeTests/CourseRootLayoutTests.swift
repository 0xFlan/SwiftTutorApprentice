import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class CourseRootLayoutTests: XCTestCase {
    private static var retainedHostedWindows: [NSWindow] = []

    func testHomeAndWorkspaceAreSeparateBoundedRoots() throws {
        let fixture = try CourseRootFixture()
        let model = fixture.makeModel()

        for size in [NSSize(width: 680, height: 520), NSSize(width: 1280, height: 860)] {
            let home = hostInWindow(
                CourseHomeView(model: model),
                size: size
            )
            defer { retainWindow(home.window) }

            assertFiniteFittingSize(home.host.fittingSize)
            XCTAssertEqual(home.host.frame.size, size)
            XCTAssertEqual(markers(named: "course-home-root", in: home.host).count, 1)
            XCTAssertTrue(markers(named: "course-workspace-root", in: home.host).isEmpty)
            let scrollView = try XCTUnwrap(
                descendant(of: NSScrollView.self, in: home.host),
                "Course Home must use a real bounded outer scroll viewport."
            )
            XCTAssertLessThanOrEqual(scrollView.frame.width, size.width)
            XCTAssertLessThanOrEqual(scrollView.frame.height, size.height)
            if size.width == 680 {
                XCTAssertGreaterThan(
                    scrollView.documentView?.frame.height ?? 0,
                    scrollView.contentView.bounds.height,
                    "The complete one-column Home document must scroll inside, not enlarge, the 680x520 viewport."
                )
            }

            try invokeNavigationAction(
                named: "course-action-swift-development",
                in: home.host
            )
            XCTAssertEqual(model.route, .course(.swiftDevelopment))
            let workspace = hostInWindow(
                CourseWorkspaceView(model: model),
                size: size
            )
            defer { retainWindow(workspace.window) }
            assertFiniteFittingSize(workspace.host.fittingSize)
            XCTAssertEqual(workspace.host.frame.size, size)
            XCTAssertTrue(markers(named: "course-home-root", in: workspace.host).isEmpty)
            XCTAssertEqual(markers(named: "course-workspace-root", in: workspace.host).count, 1)
            try invokeNavigationAction(named: "course-home-action", in: workspace.host)
            XCTAssertEqual(model.route, .courseHome)
        }
    }

    func testHomeUsesRealRootViewportAndCourseCardIdentifiers() throws {
        let fixture = try CourseRootFixture()
        let rendered = hostInWindow(
            CourseHomeView(model: fixture.makeModel()),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(markers(named: "course-home-root", in: rendered.host).count, 1)
        XCTAssertTrue(markers(named: "course-workspace-root", in: rendered.host).isEmpty)

        let viewportMarkers = markers(named: "course-home-scroll", in: rendered.host)
        XCTAssertEqual(viewportMarkers.count, 1)
        let viewport = try XCTUnwrap(viewportMarkers.first)
        let viewportFrame = frame(of: viewport, in: rendered.host)
        XCTAssertLessThanOrEqual(viewportFrame.width, 680)
        XCTAssertLessThanOrEqual(viewportFrame.height, 520)
        XCTAssertTrue(rendered.host.bounds.contains(viewportFrame))

        let cardFrames = try CourseCatalog.default.definitions.map { definition in
            let courseMarkers = markers(
                named: "course-card-\(definition.id.rawValue)",
                in: rendered.host
            )
            XCTAssertEqual(courseMarkers.count, 1)
            let marker = try XCTUnwrap(
                courseMarkers.first,
                "Missing rendered course card for \(definition.id.rawValue)."
            )
            return frame(of: marker, in: rendered.host)
        }
        XCTAssertTrue(
            cardFrames.dropFirst().allSatisfy { abs($0.minX - cardFrames[0].minX) < 1 },
            "Course Home must collapse to one card column at the minimum width."
        )
        let verticallyOrderedFrames = cardFrames.sorted { $0.minY < $1.minY }
        for pair in zip(verticallyOrderedFrames, verticallyOrderedFrames.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                pair.1.minY,
                pair.0.maxY,
                "One-column course cards must occupy distinct vertical rows."
            )
        }
    }

    func testContentViewRouteSelectsExactlyOneRoot() throws {
        let fixture = try CourseRootFixture()
        fixture.settings.hasSeenWelcome = true
        let model = fixture.makeModel()
        let rendered = hostInWindow(
            ContentView(model: model),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        assertRootIdentifiers(home: 1, workspace: 0, in: rendered.host)

        try invokeNavigationAction(
            named: "course-action-swift-development",
            in: rendered.host
        )
        refresh(rendered.host)
        assertRootIdentifiers(home: 0, workspace: 1, in: rendered.host)

        try invokeNavigationAction(named: "course-home-action", in: rendered.host)
        refresh(rendered.host)
        assertRootIdentifiers(home: 1, workspace: 0, in: rendered.host)
    }

    func testHomeCommandKeepsStableKeyboardShortcutContract() {
        XCTAssertEqual(CourseHomeNavigationCommand.keyCharacter, "h")
        XCTAssertEqual(CourseHomeNavigationCommand.modifiers, [.command, .shift])
    }

    private func assertFiniteFittingSize(_ fittingSize: NSSize) {
        XCTAssertTrue(fittingSize.width.isFinite)
        XCTAssertTrue(fittingSize.height.isFinite)
        XCTAssertGreaterThan(fittingSize.width, 0)
        XCTAssertGreaterThan(fittingSize.height, 0)
    }

    private func assertRootIdentifiers(
        home: Int,
        workspace: Int,
        in view: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            markers(named: "course-home-root", in: view).count,
            home,
            file: file,
            line: line
        )
        XCTAssertEqual(
            markers(named: "course-workspace-root", in: view).count,
            workspace,
            file: file,
            line: line
        )
    }

    private func hostInWindow<Content: View>(
        _ content: Content,
        size: NSSize
    ) -> (host: NSHostingView<Content>, window: NSWindow) {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        window.contentView = container
        window.setContentSize(size)
        window.orderFrontRegardless()
        host.frame = container.bounds
        refresh(host)
        return (host, window)
    }

    private func retainWindow(_ window: NSWindow) {
        window.animationBehavior = .none
        window.orderOut(nil)
        Self.retainedHostedWindows.append(window)
    }

    private func refresh(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        view.layoutSubtreeIfNeeded()
    }

    private func descendant<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for child in view.subviews {
            if let match = descendant(of: type, in: child) { return match }
        }
        return nil
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

    private func frame(of marker: NSView, in host: NSView) -> NSRect {
        marker.convert(marker.bounds, to: host)
    }

    private func invokeNavigationAction(named identifier: String, in view: NSView) throws {
        let marker = try XCTUnwrap(
            markers(named: identifier, in: view).first as? RuntimeNavigationActionView,
            "Missing production navigation action \(identifier)."
        )
        marker.invoke()
        refresh(view)
    }
}

@MainActor
private final class CourseRootFixture {
    let root: URL
    let settings: AppSettings
    private let lessons: LessonStore
    private let progress: ProgressStore
    private let registry: CourseContentRegistry

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CourseRootLayoutTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let lessonURL = root.appendingPathComponent("lessons.json")
        try JSONEncoder().encode(Curriculum.defaultLessons).write(to: lessonURL)
        lessons = LessonStore(fileURL: lessonURL, defaults: Curriculum.defaultLessons)
        progress = ProgressStore(
            fileURL: root.appendingPathComponent("progress.json"),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let suite = "CourseRootLayoutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        settings = AppSettings(userDefaults: defaults)
        registry = CourseContentRegistry(
            providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: lessons)]
        )
    }

    func makeModel() -> AppModel {
        AppModel(
            store: lessons,
            progress: progress,
            settings: settings,
            contentRegistry: registry
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}
