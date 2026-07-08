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

    var body: some View {
        VStack(spacing: 0) {

            navigationBar
            Divider()

            // Three resizable columns.
            HSplitView {
                LessonPanel(lesson: model.currentLesson, number: model.currentDisplayNumber)
                    .frame(minWidth: 320, idealWidth: 380)

                CodeEditorPanel(
                    code: $model.code,
                    placeholder: model.currentLesson.starterCode,
                    onInsertStarter: model.insertStarter
                )
                .frame(minWidth: 320, idealWidth: 420)

                LiveCoachPanel(
                    feedback: model.coachFeedback,
                    aiEnabled: settings.aiEnabled,
                    isAskingAI: model.isAskingAI,
                    aiResponse: model.aiResponse,
                    aiError: model.aiError,
                    onAskAI: model.askAI
                )
                .frame(minWidth: 280, idealWidth: 320)
            }
            .frame(minHeight: 360)

            Divider()

            // Bottom: run bar for code lessons, or a read-only note for
            // concept lessons (which the console runner can't execute).
            if model.currentLessonIsConcept {
                conceptFooter
                    .frame(minHeight: 220)
            } else {
                RunOutputView(
                    prediction: $model.prediction,
                    runResult: model.runResult,
                    isRunning: model.isRunning,
                    onRun: model.run
                )
                .frame(minHeight: 220)
            }
        }
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
