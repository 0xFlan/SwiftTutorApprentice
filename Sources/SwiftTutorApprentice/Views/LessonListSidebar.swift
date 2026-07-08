// LessonListSidebar.swift
// ------------------------------------------------------------
// The left-most sidebar: the list of lessons the learner can jump
// between, a running "X of N complete" count, and a reset button.
// Completed lessons show a green checkmark.
// ------------------------------------------------------------

import SwiftUI

struct LessonListSidebar: View {
    @ObservedObject var model: AppModel
    @ObservedObject var store: LessonStore
    @ObservedObject var progress: ProgressStore

    /// Called when the learner taps the "Manage lessons" button.
    let onManageLessons: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // A List whose selection is tied to the model's selected lesson.
            List(selection: Binding(
                get: { model.selectedLessonID },
                set: { newValue in if let id = newValue { model.selectLesson(id) } }
            )) {
                Section("Lessons") {
                    ForEach(store.lessons) { lesson in
                        lessonRow(lesson)
                            .tag(lesson.id)
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            // Footer: progress summary, manage lessons, reset progress.
            VStack(spacing: 8) {
                HStack {
                    Text("\(progress.completedCount) of \(store.lessons.count) complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset") {
                        progress.reset()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .help("Forget all completed lessons")
                    .disabled(progress.completedCount == 0)
                }

                Button {
                    onManageLessons()
                } label: {
                    Label("Manage lessons", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .help("Add, edit, reorder, or delete lessons — all inside the app")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(minWidth: 230)
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        HStack(spacing: 8) {
            // Completed = filled green check; not yet = hollow circle.
            Image(systemName: progress.isComplete(lesson.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(progress.isComplete(lesson.id) ? .green : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Lesson \(lesson.id)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(lesson.title)
                    .font(.callout)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
