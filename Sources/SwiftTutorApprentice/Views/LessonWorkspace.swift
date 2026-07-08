// LessonWorkspace.swift
// ------------------------------------------------------------
// The main work area (everything to the right of the lesson
// sidebar): three resizable columns on top — Lesson, Code Editor,
// Live Coach — and the Prediction + Run Output bar underneath.
// ------------------------------------------------------------

import SwiftUI

struct LessonWorkspace: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {

            // Three resizable columns.
            HSplitView {
                LessonPanel(lesson: model.currentLesson)
                    .frame(minWidth: 320, idealWidth: 380)

                CodeEditorPanel(
                    code: $model.code,
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

            // Bottom: prediction + run output.
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
