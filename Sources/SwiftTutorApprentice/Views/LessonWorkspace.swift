// LessonWorkspace.swift
// ------------------------------------------------------------
// The main work area (everything to the right of the lesson
// sidebar):
//   • a slim navigation bar (previous / next lesson + a
//     "Completed" badge and "Next lesson" nudge),
//   • three resizable columns — Lesson, Code Editor, Live Coach,
//   • the Prediction + Run Output bar underneath.
// ------------------------------------------------------------

import SwiftUI

struct LessonWorkspace: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    @ObservedObject var progress: ProgressStore

    @State private var showingDeepLesson = false
    @State private var showingModify = false
    @State private var deepLessonPresentation: LessonStagePresentation?
    @State private var modifyPresentation: LessonStagePresentation?
    @State private var scheduledDeepLessonTask: Task<Void, Never>?

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

    var body: some View {
        VStack(spacing: 0) {

            navigationBar
            Divider()

            if model.currentLesson.deepContent != nil {
                LessonStageStepper(
                    deepLessonComplete: progress.hasViewedDeepLesson(model.selectedLessonID),
                    modifyComplete: progress.hasPassedModify(model.selectedLessonID),
                    practiceComplete: progress.isComplete(model.selectedLessonID),
                    onOpenDeepLesson: openDeepLessonManually,
                    onOpenModify: openModifyManually
                )
                Divider()
            }

            if model.isPlayingWalkthrough {
                walkthroughBanner
                Divider()
            }

            // The three panels: side-by-side when there's room, otherwise a
            // segmented picker showing one full-width panel at a time. This
            // keeps every panel readable instead of compressing on small windows.
            GeometryReader { geo in
                if geo.size.width >= wideThreshold {
                    HSplitView {
                        lessonPanel.frame(minWidth: 280, idealWidth: 360)
                        codePanel.frame(minWidth: 300, idealWidth: 420)
                        coachPanel.frame(minWidth: 260, idealWidth: 320)
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("Panel", selection: $narrowPanel) {
                            ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(8)
                        Divider()
                        switch narrowPanel {
                        case .lesson: lessonPanel
                        case .code: codePanel
                        case .coach: coachPanel
                        }
                    }
                }
            }
            .frame(minHeight: 300)

            Divider()

            // Bottom: run bar for code lessons, or a read-only note for
            // concept lessons (which the console runner can't execute).
            if model.currentLessonIsConcept {
                conceptFooter
                    .frame(minHeight: 200)
            } else {
                RunOutputView(
                    prediction: $model.prediction,
                    runResult: model.runResult,
                    isRunning: model.isRunning,
                    onRun: model.run
                )
                .frame(minHeight: 200)
            }
        }
        .onAppear {
            scheduleAutomaticDeepLesson(for: model.selectedLessonID)
        }
        .onChange(of: model.selectedLessonID) { _, lessonID in
            handleLessonSelectionChange(to: lessonID)
        }
        .onChange(of: settings.hasSeenWelcome) { wasSeen, isSeen in
            guard !wasSeen, isSeen else { return }
            scheduleAutomaticDeepLesson(
                for: model.selectedLessonID,
                delayNanoseconds: 250_000_000
            )
        }
        .onDisappear {
            cancelScheduledDeepLesson()
        }
        .sheet(isPresented: $showingDeepLesson, onDismiss: {
            deepLessonPresentation = nil
        }) {
            if let presentation = deepLessonPresentation {
                DeepLessonView(
                    lesson: presentation.lesson,
                    content: presentation.content,
                    onViewed: {
                        progress.markDeepLessonViewed(presentation.lesson.id)
                    },
                    onRecallAnswer: { questionID, wasCorrect in
                        progress.recordRecallAnswer(
                            lessonID: presentation.lesson.id,
                            questionID: questionID,
                            wasCorrect: wasCorrect
                        )
                    }
                )
            } else {
                unavailableStageSheet
            }
        }
        .sheet(isPresented: $showingModify, onDismiss: {
            modifyPresentation = nil
        }) {
            if let presentation = modifyPresentation {
                ModifyTaskView(
                    task: presentation.content.modifyTask,
                    existingEditorCode: presentation.existingEditorCode,
                    onPassed: {
                        progress.markModifyPassed(presentation.lesson.id)
                    },
                    onReplaceEditor: { code, prediction in
                        guard model.selectedLessonID == presentation.lesson.id else {
                            return
                        }
                        model.code = code
                        model.prediction = prediction
                        model.runResult = nil
                    }
                )
            } else {
                unavailableStageSheet
            }
        }
    }

    // The three panels, extracted so both layouts reuse them.

    private var lessonPanel: some View {
        LessonPanel(
            lesson: model.currentLesson,
            number: model.currentDisplayNumber,
            activeTokenID: model.activeTokenID
        )
    }

    private var codePanel: some View {
        CodeEditorPanel(
            code: $model.code,
            placeholder: model.currentLesson.starterCode,
            onInsertStarter: model.insertStarter,
            isEditable: !model.isPlayingWalkthrough,
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

    private var walkthroughBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(Color.accentColor)
            Text(model.walkthroughCaption)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                model.stopWalkthrough()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.10))
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

            Button {
                if model.isPlayingWalkthrough {
                    model.stopWalkthrough()
                } else {
                    model.startWalkthrough()
                }
            } label: {
                Label(model.isPlayingWalkthrough ? "Stop" : "Walkthrough",
                      systemImage: model.isPlayingWalkthrough ? "stop.fill" : "play.circle")
            }
            .help("Play a narrated walkthrough: the code types itself in and each part is explained aloud")

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

    private var unavailableStageSheet: some View {
        VStack(spacing: 14) {
            Label("Stage unavailable", systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text("This lesson's guided content is no longer available.")
                .foregroundStyle(.secondary)

            Button("Done") {
                showingDeepLesson = false
                showingModify = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 220)
    }

    private func currentStagePresentation() -> LessonStagePresentation? {
        let lesson = model.currentLesson
        guard lesson.id == model.selectedLessonID,
              let content = lesson.deepContent
        else {
            return nil
        }

        return LessonStagePresentation(
            lesson: lesson,
            content: content,
            existingEditorCode: model.code
        )
    }

    private func openDeepLessonManually() {
        cancelScheduledDeepLesson()
        guard let presentation = currentStagePresentation() else { return }
        modifyPresentation = nil
        showingModify = false
        deepLessonPresentation = presentation
        showingDeepLesson = true
    }

    private func openModifyManually() {
        cancelScheduledDeepLesson()
        guard let presentation = currentStagePresentation() else { return }
        deepLessonPresentation = nil
        showingDeepLesson = false
        modifyPresentation = presentation
        showingModify = true
    }

    private func handleLessonSelectionChange(to lessonID: Int) {
        cancelScheduledDeepLesson()
        showingDeepLesson = false
        showingModify = false
        deepLessonPresentation = nil
        modifyPresentation = nil
        scheduleAutomaticDeepLesson(for: lessonID)
    }

    private func scheduleAutomaticDeepLesson(
        for lessonID: Int,
        delayNanoseconds: UInt64 = 0
    ) {
        cancelScheduledDeepLesson()

        guard settings.hasSeenWelcome,
              lessonID == model.selectedLessonID,
              model.store.lesson(id: lessonID)?.deepContent != nil,
              !progress.hasViewedDeepLesson(lessonID)
        else {
            return
        }

        scheduledDeepLessonTask = Task { @MainActor in
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            await Task.yield()

            guard !Task.isCancelled,
                  settings.hasSeenWelcome,
                  model.selectedLessonID == lessonID,
                  !progress.hasViewedDeepLesson(lessonID),
                  !showingDeepLesson,
                  !showingModify,
                  let lesson = model.store.lesson(id: lessonID),
                  let content = lesson.deepContent
            else {
                return
            }

            scheduledDeepLessonTask = nil
            deepLessonPresentation = LessonStagePresentation(
                lesson: lesson,
                content: content,
                existingEditorCode: model.code
            )
            showingDeepLesson = true
        }
    }

    private func cancelScheduledDeepLesson() {
        scheduledDeepLessonTask?.cancel()
        scheduledDeepLessonTask = nil
    }
}

private struct LessonStagePresentation {
    let lesson: Lesson
    let content: LessonDeepContent
    let existingEditorCode: String
}
