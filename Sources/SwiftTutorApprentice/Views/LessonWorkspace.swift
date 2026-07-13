// LessonWorkspace.swift
// ------------------------------------------------------------
// The main work area (everything to the right of the lesson
// sidebar):
//   • a slim navigation bar (previous / next lesson + a
//     "Completed" badge and "Next lesson" nudge),
//   • three resizable columns — Lesson, Code Editor, Live Coach,
//   • the Prediction + Run Output bar underneath.
// ------------------------------------------------------------

import AppKit
import SwiftUI

struct PersistenceBannerRuntimeMarker: NSViewRepresentable {
    let identifier: String
    let titleText: String
    let detailText: String
    let fileURL: URL
    let retryCommand: RuntimeNavigationCommand?
    let revealCommand: RuntimeNavigationCommand

    func makeNSView(context: Context) -> PersistenceBannerRuntimeView {
        PersistenceBannerRuntimeView(
            identifier: identifier,
            titleText: titleText,
            detailText: detailText,
            fileURL: fileURL,
            retryCommand: retryCommand,
            revealCommand: revealCommand
        )
    }

    func updateNSView(_ nsView: PersistenceBannerRuntimeView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier(identifier)
        nsView.titleText = titleText
        nsView.detailText = detailText
        nsView.fileURL = fileURL
        nsView.retryCommand = retryCommand
        nsView.revealCommand = revealCommand
    }
}

final class PersistenceBannerRuntimeView: NSView {
    var titleText: String
    var detailText: String
    var fileURL: URL
    var retryCommand: RuntimeNavigationCommand?
    var revealCommand: RuntimeNavigationCommand

    init(
        identifier: String,
        titleText: String,
        detailText: String,
        fileURL: URL,
        retryCommand: RuntimeNavigationCommand?,
        revealCommand: RuntimeNavigationCommand
    ) {
        self.titleText = titleText
        self.detailText = detailText
        self.fileURL = fileURL
        self.retryCommand = retryCommand
        self.revealCommand = revealCommand
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct PersistenceBannerContent: Equatable {
    enum Kind: Equatable {
        case progressUnsupported
        case progressCorrupt
        case progressSaveError
        case lessonContentReadOnly
    }

    let kind: Kind
    let identifier: String
    let title: String
    let detail: String
    let fileURL: URL

    init?(progress: ProgressStore) {
        if progress.isReadOnlyForUnsupportedVersion {
            self.init(
                kind: .progressUnsupported,
                identifier: "progress-unsupported",
                title: "Progress is read-only",
                detail: "This progress file was created by a newer app version. Changes are blocked to preserve its exact bytes. You can still study lessons and run code.",
                fileURL: progress.persistenceURL
            )
        } else if progress.loadError != nil {
            self.init(
                kind: .progressCorrupt,
                identifier: "progress-corrupt",
                title: "Progress file couldn't be safely opened",
                detail: "This progress file is damaged or invalid. Progress is read-only to preserve its exact bytes. You can still study lessons and run code.",
                fileURL: progress.persistenceURL
            )
        } else if progress.saveError != nil {
            self.init(
                kind: .progressSaveError,
                identifier: "progress-save-error",
                title: "Progress hasn't been saved",
                detail: "Your latest progress is still in memory. Retry saving, or reveal the local progress file to inspect its location.",
                fileURL: progress.persistenceURL
            )
        } else {
            return nil
        }
    }

    init?(lessonStore: LessonStore) {
        guard lessonStore.isReadOnlyForUnsupportedLessonContent else {
            return nil
        }
        self.init(
            kind: .lessonContentReadOnly,
            identifier: "lesson-content-read-only",
            title: "Lesson content is read-only",
            detail: "This lesson file contains newer or unsupported lesson content. Editing and automatic enrichment are disabled to preserve its exact bytes. You can still study available lessons and run code.",
            fileURL: lessonStore.persistenceURL
        )
    }

    private init(
        kind: Kind,
        identifier: String,
        title: String,
        detail: String,
        fileURL: URL
    ) {
        self.kind = kind
        self.identifier = identifier
        self.title = title
        self.detail = detail
        self.fileURL = fileURL
    }
}

struct LocalPersistenceBanner: View {
    let content: PersistenceBannerContent
    let retry: (() -> Void)?
    let revealFile: (URL) -> Void

    var body: some View {
        let revealCommand = RuntimeNavigationCommand(
            identifier: "\(content.identifier)-reveal",
            action: { revealFile(content.fileURL) }
        )
        let retryCommand = retry.map { retryAction in
            RuntimeNavigationCommand(
                identifier: "\(content.identifier)-retry",
                action: retryAction
            )
        }

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(content.title)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)

                Text(content.detail)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if let retryCommand {
                        Button("Retry", action: retryCommand.invoke)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }

                    Button("Reveal File", action: revealCommand.invoke)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.11))
        .background {
            PersistenceBannerRuntimeMarker(
                identifier: content.identifier,
                titleText: content.title,
                detailText: content.detail,
                fileURL: content.fileURL,
                retryCommand: retryCommand,
                revealCommand: revealCommand
            )
        }
        .accessibilityElement(children: .contain)
    }
}

struct LessonWorkspaceReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: LessonWorkspaceSession
    let initialAction: () -> Void

    init(
        session: LessonWorkspaceSession,
        initialAction: @escaping () -> Void = {}
    ) {
        self.session = session
        self.initialAction = initialAction
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                session.updateReduceMotion(reduceMotion)
                initialAction()
            }
            .onChange(of: reduceMotion) { _, newValue in
                session.updateReduceMotion(newValue)
            }
    }
}

struct LessonWorkspace: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var progress: ProgressStore
    @ObservedObject var scrollCoordinator: LessonScrollCoordinator
    let canPresentLearningStages: Bool
    let revealFile: (URL) -> Void

    @StateObject private var session = LessonWorkspaceSession()
    @State private var workspaceCancellationToken: UUID?
    @FocusState private var practiceWorkspaceIsFocused: Bool

    /// Which single panel to show when the window is too narrow for 3 columns.
    private enum Panel: String, CaseIterable, Identifiable {
        case lesson = "Lesson"
        case code = "Code"
        case coach = "Coach"
        var id: String { rawValue }
    }
    @State private var narrowPanel: Panel = .code

    /// Below this width the three columns would squish, so we switch to a
    /// tabbed single-panel layout instead.
    private let wideThreshold: CGFloat = 860
    /// At the supported minimum window size, reserve enough height for the
    /// picker, internally scrolling editor, run output, and split dividers.
    private let minimumWorkspaceHeight: CGFloat = 412
    private let upperPaneMinimumHeight: CGFloat = 326
    private let outputPaneMinimumHeight: CGFloat = 80

    init(
        model: AppModel,
        settings: AppSettings,
        progress: ProgressStore,
        scrollCoordinator: LessonScrollCoordinator,
        canPresentLearningStages: Bool,
        revealFile: @escaping (URL) -> Void = { url in
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    ) {
        self.model = model
        self.settings = settings
        self.progress = progress
        self.scrollCoordinator = scrollCoordinator
        self.canPresentLearningStages = canPresentLearningStages
        self.revealFile = revealFile
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar
            Divider()

            GeometryReader { detailGeometry in
                lessonDocument(viewportHeight: detailGeometry.size.height)
                .frame(
                    width: detailGeometry.size.width,
                    height: detailGeometry.size.height,
                    alignment: .topLeading
                )
            }
        }
        .modifier(
            LessonWorkspaceReduceMotionModifier(session: session) {
                activateCurrentLessonSession()
                registerWorkspaceCancellation()
            }
        )
        .onChange(of: model.selectedLessonKey) { _, _ in
            activateCurrentLessonSession()
            registerWorkspaceCancellation()
        }
        .onChange(of: canPresentLearningStages) { _, isAllowed in
            if isAllowed {
                activateCurrentLessonSession()
                registerWorkspaceCancellation()
            } else {
                session.cancel()
            }
        }
        .onDisappear {
            if let workspaceCancellationToken {
                model.unregisterWorkspaceCancellation(workspaceCancellationToken)
                self.workspaceCancellationToken = nil
            }
            session.cancel()
        }
        .sheet(item: $session.activeLessonStage) { stage in
            switch stage {
            case .deepLesson(let presentation):
                DeepLessonView(
                    lesson: presentation.lesson,
                    content: presentation.content,
                    onViewed: {
                        progress.markDeepLessonViewed(presentation.lessonKey)
                    },
                    onRecallAnswer: { questionID, wasCorrect in
                        progress.recordRecallAnswer(
                            lessonKey: presentation.lessonKey,
                            questionID: questionID,
                            wasCorrect: wasCorrect
                        )
                    }
                )
            case .modify(let presentation):
                ModifyTaskView(
                    task: presentation.content.modifyTask,
                    existingEditorCode: presentation.existingEditorCode,
                    progressCanBeSaved: !progress.isReadOnlyForUnsupportedVersion
                        && progress.loadError == nil,
                    onPassed: {
                        session.recordModifyPassed(
                            presentation,
                            progress: progress
                        )
                    },
                    onReplaceEditor: { code, prediction in
                        guard session.canReplaceEditor(
                            for: presentation,
                            selectedLessonKey: model.selectedLessonKey
                        ) else {
                            return
                        }
                        model.code = code
                        model.prediction = prediction
                        model.runResult = nil
                    }
                )
            }
        }
    }

    private var selectedLessonKey: LessonKey {
        model.selectedLessonKey ?? .swift(model.selectedLessonID)
    }

    @MainActor
    static func playerExpansionCommand(
        session: LessonWorkspaceSession,
        owningLessonKey: LessonKey
    ) -> @MainActor () -> Void {
        return {
            session.recordPlayerExpanded(for: owningLessonKey)
        }
    }

    private func lessonDocument(viewportHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id("detail-top")
                        .background {
                            RuntimeViewMarker(identifier: "detail-top")
                        }

                    if let controller = session.controller {
                        LessonPresentationPlayer(
                            controller: controller,
                            initiallyExpanded: session.playerExpansionLessonKey == selectedLessonKey,
                            expansionRequestGeneration: session.playerExpansionGeneration,
                            deactivatesOnDisappear: false,
                            showsReadDeeper: model.currentLesson.deepContent != nil,
                            onExpanded: Self.playerExpansionCommand(
                                session: session,
                                owningLessonKey: controller.lessonKey
                            ),
                            onReadDeeper: openDeepLessonManually
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    } else if model.currentLesson.hasUnsupportedPresentation {
                        LessonPresentationUnavailablePlayer(
                            showsReadDeeper: model.currentLesson.deepContent != nil,
                            onReadDeeper: openDeepLessonManually
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }

                    lessonDocumentHeader

                    if showsLessonStagePath {
                        LessonStageStepper(
                            watchStatus: presentationStatusText,
                            recallStatus: recallStatusText,
                            modifyComplete: progress.hasPassedModify(selectedLessonKey),
                            practiceComplete: progress.isComplete(selectedLessonKey),
                            onOpenWatch: session.openWatch,
                            onOpenRecall: {
                                session.requestRecallFocus(for: selectedLessonKey)
                            },
                            onOpenModify: openModifyManually,
                            watchEnabled: session.controller.map {
                                $0.entryMode != .unavailable
                            } ?? false,
                            recallEnabled: linkedRecallQuestion != nil,
                            modifyEnabled: model.currentLesson.deepContent != nil
                        )
                        Divider()
                    }

                    if let content = PersistenceBannerContent(
                        lessonStore: model.store
                    ) {
                        LocalPersistenceBanner(
                            content: content,
                            retry: nil,
                            revealFile: revealFile
                        )
                        Divider()
                    }

                    if let content = PersistenceBannerContent(progress: progress) {
                        LocalPersistenceBanner(
                            content: content,
                            retry: content.kind == .progressSaveError
                                ? progress.retrySave
                                : nil,
                            revealFile: revealFile
                        )
                        Divider()
                    }

                    if let linkedRecallQuestion {
                        let recallLessonKey = selectedLessonKey
                        LessonRecallView(
                            question: linkedRecallQuestion,
                            focusGeneration: session.activeRecallFocusGeneration(
                                for: recallLessonKey
                            ),
                            showsContinue: true,
                            persistedWasCorrect: progress.recallAnswer(
                                for: recallLessonKey,
                                questionID: linkedRecallQuestion.id
                            ),
                            onAnswer: { questionID, wasCorrect in
                                session.recordRecallAnswer(
                                    lessonKey: recallLessonKey,
                                    questionID: questionID,
                                    wasCorrect: wasCorrect,
                                    progress: progress
                                )
                            },
                            onFocusApplied: { generation in
                                session.acknowledgeRecallFocus(
                                    generation: generation,
                                    lessonKey: recallLessonKey
                                )
                            },
                            onContinue: {
                                session.continueAfterRecall(
                                    modify: currentStagePresentation()
                                )
                            }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider()
                    }

                    if let presentation = model.currentLesson.presentation,
                       let exercise = presentation.aiCodeExercise {
                        AICodeReviewView(exercise: exercise) { evaluation in
                            session.submitAICodeReview(
                                evaluation,
                                lessonKey: selectedLessonKey,
                                presentation: presentation,
                                exercise: exercise,
                                progress: progress
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        Divider()
                    }

                    practiceWorkspace
                        .frame(
                            height: max(
                                minimumWorkspaceHeight,
                                viewportHeight - 32
                            )
                        )
                        .background {
                            RuntimeViewMarker(identifier: "practice-workspace")
                        }
                }
                .id(selectedLessonKey)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background {
                    ScrollViewportProbe(identifier: "lesson-document-scroll")
                }
            }
            .task(id: scrollCoordinator.detailTopGeneration) {
                guard scrollCoordinator.detailTopGeneration > 0 else { return }
                await Task.yield()
                proxy.scrollTo("detail-top", anchor: .top)
            }
            .task(id: session.recallFocusGeneration) {
                guard let request = session.recallFocusRequest,
                      request.generation > 0,
                      request.lessonKey == selectedLessonKey,
                      let linkedRecallQuestion
                else { return }
                await Task.yield()
                guard !Task.isCancelled,
                      session.recallFocusGeneration == request.generation,
                      selectedLessonKey == request.lessonKey
                else { return }
                proxy.scrollTo(
                    "lesson-recall-\(linkedRecallQuestion.id)",
                    anchor: .center
                )
                session.acknowledgeRecallScroll(
                    generation: request.generation,
                    lessonKey: request.lessonKey
                )
            }
        }
    }

    private var lessonDocumentHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Lesson \(model.currentDisplayNumber)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(model.currentLesson.title)
                .font(.title2.bold())
            Text(model.currentLesson.goal)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RuntimeViewMarker(identifier: "lesson-document-header")
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var practiceWorkspace: some View {
        VSplitView {
            upperWorkspace
                .frame(
                    minHeight: upperPaneMinimumHeight,
                    idealHeight: upperPaneMinimumHeight,
                    maxHeight: .infinity
                )
                .background {
                    RuntimeViewMarker(identifier: "workspace-upper-pane")
                }

            outputWorkspace
                .frame(
                    minHeight: outputPaneMinimumHeight,
                    idealHeight: 90,
                    maxHeight: .infinity
                )
                .background {
                    RuntimeViewMarker(identifier: "run-output-pane")
                }
        }
    }

    @ViewBuilder
    private var upperWorkspace: some View {
        GeometryReader { geometry in
            if geometry.size.width >= wideThreshold {
                HSplitView {
                    lessonPanel.frame(minWidth: 280, idealWidth: 360)
                    codePanel.frame(minWidth: 300, idealWidth: 420)
                    coachPanel.frame(minWidth: 260, idealWidth: 320)
                }
                .background {
                    RuntimeViewMarker(identifier: "wide-workspace-split")
                }
            } else {
                VStack(spacing: 0) {
                    Picker("Panel", selection: $narrowPanel) {
                        ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                    .frame(height: 44)
                    .background {
                        RuntimeViewMarker(identifier: "narrow-panel-picker")
                    }

                    Divider()

                    Group {
                        switch narrowPanel {
                        case .lesson: lessonPanel
                        case .code: codePanel
                        case .coach: coachPanel
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        RuntimeViewMarker(identifier: "narrow-selected-panel")
                    }
                    .clipped()
                }
            }
        }
    }

    @ViewBuilder
    private var outputWorkspace: some View {
        Group {
            if model.currentLessonIsConcept {
                conceptFooter
            } else {
                RunOutputView(
                    prediction: $model.prediction,
                    runResult: model.runResult,
                    isRunning: model.isRunning,
                    onRun: model.run
                )
            }
        }
        .focusable()
        .focused($practiceWorkspaceIsFocused)
        .accessibilityIdentifier("practice-run-workspace")
        .task(id: session.practiceFocusGeneration) {
            guard session.practiceFocusGeneration > 0 else { return }
            narrowPanel = .code
            await Task.yield()
            practiceWorkspaceIsFocused = true
        }
    }

    // The three panels, extracted so both layouts reuse them.

    private var lessonPanel: some View {
        LessonPanel(lesson: model.currentLesson)
    }

    private var codePanel: some View {
        CodeEditorPanel(
            code: $model.code,
            placeholder: model.currentLesson.starterCode,
            onInsertStarter: model.insertStarter,
            isEditable: true,
            practiceEnabled: !model.currentLessonIsConcept
        )
    }

    private var coachPanel: some View {
        LiveCoachPanel(
            feedback: model.coachFeedback,
            aiEnabled: settings.aiEnabled,
            isAskingAI: model.isAskingAI,
            aiResponse: model.aiResponse,
            aiError: model.aiError,
            onAskAI: model.askAI
        )
    }

    private var conceptFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Read-only concept lesson", systemImage: "book")
                .font(.headline)
                .foregroundStyle(Color.accentColor)

            Text("""
            This lesson is about understanding, not running. SwiftUI builds a \
            graphical interface, which this app's console runner can't display — \
            so there's no Run step. Read the lesson and the Syntax Lens on the \
            left, then mark it read.
            """)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if progress.isComplete(model.selectedLessonID) {
                    Label("Read", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else if progress.isReadOnlyForUnsupportedVersion
                    || progress.loadError != nil {
                    Label("Progress read-only", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                        .help("Mark as read is unavailable while the local progress file is read-only.")
                } else {
                    Button {
                        model.markCurrentLessonRead()
                    } label: {
                        Label("Mark as read", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navigationBar: some View {
        HStack(spacing: 10) {
            Button {
                model.goToPreviousLesson()
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(!model.hasPreviousLesson)
            .keyboardShortcut("[", modifiers: .command)

            Button {
                model.goToNextLesson()
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(!model.hasNextLesson)
            .keyboardShortcut("]", modifiers: .command)

            if model.currentLesson.presentation == nil,
               model.currentLesson.deepContent != nil {
                Button("Read deeper", action: openDeepLessonManually)
                    .help("Open the optional written Deep Lesson")
                    .background {
                        RuntimeViewMarker(identifier: "read-deeper-button")
                    }
                Button("Modify", action: openModifyManually)
                    .help("Open the guided code modification task")
                    .background {
                        RuntimeViewMarker(identifier: "modify-button")
                    }
            }

            Spacer()

            if progress.isComplete(model.selectedLessonID) {
                Label("Completed", systemImage: "checkmark.seal.fill")
                    .font(.callout.bold())
                    .foregroundStyle(.green)
                    .transition(.opacity)

                if model.hasNextLesson {
                    Button {
                        model.goToNextLesson()
                    } label: {
                        Label("Next lesson", systemImage: "arrow.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: progress.isComplete(model.selectedLessonID))
    }

    private func currentStagePresentation() -> LessonStagePresentation? {
        let lesson = model.currentLesson
        guard lesson.id == model.selectedLessonID,
              let content = lesson.deepContent
        else {
            return nil
        }

        return LessonStagePresentation(
            lessonKey: selectedLessonKey,
            lesson: lesson,
            content: content,
            existingEditorCode: model.code
        )
    }

    private func openDeepLessonManually() {
        guard let presentation = currentStagePresentation() else { return }
        session.activeLessonStage = .deepLesson(presentation)
    }

    private func openModifyManually() {
        guard let presentation = currentStagePresentation() else { return }
        session.activeLessonStage = .modify(presentation)
    }

    private func activateCurrentLessonSession() {
        guard canPresentLearningStages else {
            session.cancel()
            return
        }
        let lesson = model.currentLesson
        session.activate(
            for: selectedLessonKey,
            presentation: lesson.presentation,
            savedState: progress.presentationState(for: selectedLessonKey),
            persist: { key, state in
                progress.setPresentationState(state, for: key)
            }
        )
    }

    private func registerWorkspaceCancellation() {
        if let workspaceCancellationToken {
            model.unregisterWorkspaceCancellation(workspaceCancellationToken)
        }
        let session = session
        workspaceCancellationToken = model.registerWorkspaceCancellation { [weak session] in
            session?.cancel()
        }
    }

    private var linkedRecallQuestion: RecallQuestion? {
        guard let deepContent = model.currentLesson.deepContent else { return nil }
        if let presentation = model.currentLesson.presentation {
            return deepContent.recallQuestions.first {
                $0.id == presentation.finalRecallQuestionID
            }
        }
        guard model.currentLesson.hasUnsupportedPresentation else { return nil }
        return deepContent.recallQuestions.first
    }

    private var showsLessonStagePath: Bool {
        canPresentLearningStages
            && (session.controller != nil || model.currentLesson.hasUnsupportedPresentation)
    }

    private var recallStatusText: String {
        guard let questionID = linkedRecallQuestion?.id else { return "Unavailable" }
        return progress.recallAnswer(for: selectedLessonKey, questionID: questionID) == nil
            ? "Not answered"
            : "Answered"
    }

    private var presentationStatusText: String {
        if session.controller?.entryMode == .unavailable {
            return "Unavailable"
        }
        if model.currentLesson.hasUnsupportedPresentation,
           session.controller == nil {
            return "Unavailable"
        }
        switch progress.presentationState(for: selectedLessonKey)?.status {
        case .started: return "In progress"
        case .skipped: return "Skipped · Replayable"
        case .completed: return "Complete"
        case .notStarted, nil: return session.controller == nil ? "Unavailable" : "Not started"
        }
    }
}
