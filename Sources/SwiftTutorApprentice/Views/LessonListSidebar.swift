// LessonListSidebar.swift
// ------------------------------------------------------------
// The left-most sidebar: the list of lessons the learner can jump
// between, a running "X of N complete" count, and a reset button.
// Completed lessons show a green checkmark.
// ------------------------------------------------------------

import AppKit
import SwiftUI

struct LessonListSidebar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: LessonStore
    @ObservedObject var progress: ProgressStore
    @ObservedObject var scrollCoordinator: LessonScrollCoordinator
    @StateObject private var nativeSidebar = NativeLessonSidebarController()

    /// Called when the learner taps the "Manage lessons" button.
    let onManageLessons: () -> Void
    /// Called when the learner taps the settings button.
    let onOpenSettings: () -> Void
    /// Reveals a store's exact local file. Tests inject a capturing closure so
    /// hosted interactions never open Finder.
    let revealFile: (URL) -> Void

    init(
        model: AppModel,
        store: LessonStore,
        progress: ProgressStore,
        scrollCoordinator: LessonScrollCoordinator,
        onManageLessons: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        revealFile: @escaping (URL) -> Void = { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    ) {
        self.model = model
        self.store = store
        self.progress = progress
        self.scrollCoordinator = scrollCoordinator
        self.onManageLessons = onManageLessons
        self.onOpenSettings = onOpenSettings
        self.revealFile = revealFile
    }

    var body: some View {
        let progressRevealCommand = RuntimeNavigationCommand(
            identifier: "reveal-progress-file-sidebar",
            action: { revealFile(progress.persistenceURL) }
        )
        let lessonsRevealCommand = RuntimeNavigationCommand(
            identifier: "reveal-lessons-file-sidebar",
            action: { revealFile(store.persistenceURL) }
        )

        VStack(alignment: .leading, spacing: 0) {

            ScrollViewReader { proxy in
                List(selection: Binding<LessonKey?>(
                    get: { model.selectedLessonKey },
                    set: { key in
                        if let key {
                            model.selectLesson(key, origin: .direct)
                        }
                    }
                )) {
                    Section("Lessons") {
                        ForEach(sidebarLessons) { item in
                            lessonRow(
                                item.lesson,
                                key: item.id,
                                number: item.number,
                                probesListViewport: item.number == 1
                            )
                                .tag(item.id)
                                .id(item.id)
                        }
                    }
                }
                .listStyle(.sidebar)
                .task(id: scrollCoordinator.sidebarVisibilityRequest?.id) {
                    guard let request = scrollCoordinator.sidebarVisibilityRequest else {
                        return
                    }
                    await Task.yield()
                    guard !Task.isCancelled,
                          scrollCoordinator.sidebarVisibilityRequest == request
                    else { return }
                    let lessonKeys = sidebarLessons.map(\.id)
                    switch request.alignment {
                    case .center:
                        nativeSidebar.reveal(
                            request.lessonKey,
                            orderedKeys: lessonKeys,
                            alignment: .center
                        )
                        proxy.scrollTo(request.lessonKey, anchor: .center)
                    case .nearest:
                        if nativeSidebar.reveal(
                            request.lessonKey,
                            orderedKeys: lessonKeys,
                            alignment: .nearest
                        ) == .alreadyVisible {
                            scrollCoordinator.fulfillSidebarVisibilityRequest(request)
                            return
                        }
                        proxy.scrollTo(request.lessonKey)
                        // macOS 14 can ignore an unanchored List scroll when
                        // the destination row has not been mounted yet. Give
                        // the nearest-edge command one render turn, then use a
                        // centered fallback only if a visible row probe has
                        // not already consumed the request.
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        guard !Task.isCancelled,
                              scrollCoordinator.sidebarVisibilityRequest == request
                        else { return }
                        nativeSidebar.reveal(
                            request.lessonKey,
                            orderedKeys: lessonKeys,
                            alignment: .center
                        )
                        proxy.scrollTo(request.lessonKey, anchor: .center)
                    }
                }
            }

            Divider()

            // Footer: progress summary, manage lessons, reset progress.
            HStack(spacing: 6) {
                Text("\(progress.completedCount)/\(store.lessons.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "\(progress.completedCount) of \(store.lessons.count) lessons complete"
                    )

                Spacer(minLength: 0)

                Button("Reset") {
                    progress.reset()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help(resetHelp)
                .disabled(resetIsDisabled)

                if progress.isReadOnlyForUnsupportedVersion
                    || progress.loadError != nil
                    || progress.saveError != nil {
                    Button(action: progressRevealCommand.invoke) {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("Reveal progress file")
                    .help("Show the local progress file in Finder")
                    .background {
                        RuntimeNavigationActionMarker(command: progressRevealCommand)
                    }
                }

                Button(action: onManageLessons) {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Manage lessons")
                .help(manageLessonsHelp)
                .disabled(store.isReadOnlyForUnsupportedDeepContent)

                if store.isReadOnlyForUnsupportedLessonContent {
                    Button(action: lessonsRevealCommand.invoke) {
                        Image(systemName: "folder")
                    }
                    .accessibilityLabel("Reveal lesson file")
                    .help("Show the local lesson file in Finder")
                    .background {
                        RuntimeNavigationActionMarker(command: lessonsRevealCommand)
                    }
                }

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                .help("Preferences, including the optional AI coach")
            }
            .controlSize(.small)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                RuntimeViewMarker(identifier: "course-sidebar-footer")
            }
        }
        .frame(minWidth: 230)
    }

    private var sidebarLessons: [SidebarLessonItem] {
        store.lessons.enumerated().map { index, lesson in
            SidebarLessonItem(
                id: .swift(lesson.id),
                number: index + 1,
                lesson: lesson
            )
        }
    }

    private func lessonRow(
        _ lesson: Lesson,
        key: LessonKey,
        number: Int,
        probesListViewport: Bool
    ) -> some View {
        HStack(spacing: 8) {
            // Completed = filled green check; not yet = hollow circle.
            Image(systemName: progress.isComplete(key) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(progress.isComplete(key) ? .green : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Lesson \(number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(lesson.title)
                    .font(.callout)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .background {
            ZStack {
                SidebarLessonRowProbe(
                    identifier: "lesson-row-\(key.id)",
                    request: scrollCoordinator.sidebarVisibilityRequest,
                    lessonKey: key,
                    onMeaningfullyVisible: { request in
                        scrollCoordinator.fulfillSidebarVisibilityRequest(request)
                    }
                )
                if probesListViewport {
                    ScrollViewportProbe(
                        identifier: "lesson-sidebar-scroll",
                        onResolve: { nativeSidebar.register($0) }
                    )
                }
            }
        }
    }

    private var resetIsDisabled: Bool {
        progress.isReadOnlyForUnsupportedVersion
            || progress.loadError != nil
            || (progress.completedLessonIDs.isEmpty && progress.stageEvents.isEmpty)
    }

    private var resetHelp: String {
        if progress.isReadOnlyForUnsupportedVersion {
            return "Reset is unavailable because this progress file was created by a newer app version."
        }

        if progress.loadError != nil {
            return "Reset is unavailable because this progress file could not be safely opened."
        }

        return "Clear completed lessons and all Deep Lesson and Modify activity"
    }

    private var manageLessonsHelp: String {
        if store.isReadOnlyForUnsupportedDeepContent {
            return "Lesson editing is unavailable because this lesson file contains newer or unsupported lesson content."
        }

        return "Add, edit, reorder, or delete lessons — all inside the app"
    }
}

private enum NativeLessonRevealResult {
    case unavailable
    case alreadyVisible
    case scrolled
}

@MainActor
private final class NativeLessonSidebarController: ObservableObject {
    private weak var scrollView: NSScrollView?

    func register(_ scrollView: NSScrollView) {
        self.scrollView = scrollView
    }

    @discardableResult
    func reveal(
        _ lessonKey: LessonKey,
        orderedKeys: [LessonKey],
        alignment: SidebarVisibilityAlignment
    ) -> NativeLessonRevealResult {
        guard let scrollView,
              let documentView = scrollView.documentView,
              let index = orderedKeys.firstIndex(of: lessonKey),
              !orderedKeys.isEmpty
        else { return .unavailable }

        if let row = descendant(
            named: "lesson-row-\(lessonKey.id)",
            in: documentView
        ) {
            let rowFrame = row.convert(row.bounds, to: documentView)
            let visibleHeight = rowFrame.intersection(scrollView.documentVisibleRect).height
            if rowFrame.height > 0,
               visibleHeight >= min(8, rowFrame.height) {
                return .alreadyVisible
            }

            scroll(
                scrollView,
                to: offset(
                    for: rowFrame,
                    in: scrollView,
                    alignment: alignment
                )
            )
            return .scrolled
        }

        let documentHeight = documentView.bounds.height
        let viewportHeight = scrollView.contentView.bounds.height
        let maximumOffset = max(0, documentHeight - viewportHeight)
        let fraction = CGFloat(index) / CGFloat(max(1, orderedKeys.count - 1))
        scroll(scrollView, to: maximumOffset * fraction)
        return .scrolled
    }

    private func descendant(named identifier: String, in view: NSView) -> NSView? {
        if view.identifier?.rawValue == identifier {
            return view
        }
        for child in view.subviews {
            if let match = descendant(named: identifier, in: child) {
                return match
            }
        }
        return nil
    }

    private func offset(
        for rowFrame: NSRect,
        in scrollView: NSScrollView,
        alignment: SidebarVisibilityAlignment
    ) -> CGFloat {
        let viewport = scrollView.documentVisibleRect
        let maximumOffset = max(
            0,
            (scrollView.documentView?.bounds.height ?? 0) - viewport.height
        )
        let desired: CGFloat
        switch alignment {
        case .center:
            desired = rowFrame.midY - (viewport.height / 2)
        case .nearest:
            if rowFrame.minY < viewport.minY {
                desired = rowFrame.minY
            } else {
                desired = rowFrame.maxY - viewport.height
            }
        }
        return min(max(0, desired), maximumOffset)
    }

    private func scroll(_ scrollView: NSScrollView, to verticalOffset: CGFloat) {
        let current = scrollView.contentView.bounds.origin
        scrollView.contentView.scroll(to: NSPoint(x: current.x, y: verticalOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

private struct SidebarLessonRowProbe: NSViewRepresentable {
    let identifier: String
    let request: SidebarVisibilityRequest?
    let lessonKey: LessonKey
    let onMeaningfullyVisible: @MainActor (SidebarVisibilityRequest) -> Void

    func makeNSView(context: Context) -> SidebarLessonRowProbeView {
        SidebarLessonRowProbeView(identifier: identifier)
    }

    func updateNSView(_ nsView: SidebarLessonRowProbeView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier(identifier)
        nsView.request = request?.lessonKey == lessonKey ? request : nil
        nsView.onMeaningfullyVisible = onMeaningfullyVisible
        nsView.reportVisibilityAfterLayout()
    }
}

private final class SidebarLessonRowProbeView: NSView {
    var request: SidebarVisibilityRequest?
    var onMeaningfullyVisible: (@MainActor (SidebarVisibilityRequest) -> Void)?

    init(identifier: String) {
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        reportVisibilityAfterLayout()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportVisibilityAfterLayout()
    }

    func reportVisibilityAfterLayout() {
        DispatchQueue.main.async { [weak self] in
            self?.reportVisibility()
        }
    }

    private func reportVisibility() {
        guard let request,
              let onMeaningfullyVisible,
              let scrollView = self.enclosingScrollView,
              let documentView = scrollView.documentView
        else { return }

        let rowFrame = convert(bounds, to: documentView)
        let visibleHeight = rowFrame.intersection(scrollView.documentVisibleRect).height
        guard rowFrame.height > 0,
              visibleHeight >= min(8, rowFrame.height)
        else { return }
        onMeaningfullyVisible(request)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct SidebarLessonItem: Identifiable {
    let id: LessonKey
    let number: Int
    let lesson: Lesson
}
