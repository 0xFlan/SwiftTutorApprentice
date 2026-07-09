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
    }

    // The three panels, extracted so both layouts reuse them.

    private var lessonPanel: some View {
        LessonPanel(lesson: model.currentLesson, number: model.currentDisplayNumber)
    }

    private var codePanel: some View {
        CodeEditorPanel(
            code: $model.code,
            placeholder: model.currentLesson.starterCode,
            onInsertStarter: model.insertStarter
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
}
