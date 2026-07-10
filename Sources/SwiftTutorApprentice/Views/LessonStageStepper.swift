// LessonStageStepper.swift
// ------------------------------------------------------------
// A compact, non-locking guide to the recommended learning path.
// Deep Lesson and Modify remain replayable at every stage; the
// existing lesson workspace is always available beneath it.
// ------------------------------------------------------------

import SwiftUI

struct LessonStageStepper: View {
    let deepLessonComplete: Bool
    let modifyComplete: Bool
    let practiceComplete: Bool
    let onOpenDeepLesson: () -> Void
    let onOpenModify: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalPath
                .fixedSize(horizontal: true, vertical: false)

            verticalPath
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.055))
        .accessibilityElement(children: .contain)
    }

    private var horizontalPath: some View {
        HStack(spacing: 10) {
            deepLessonButton(expanded: false)
            connector(systemImage: "arrow.right")
            modifyButton(expanded: false)
            connector(systemImage: "arrow.right")
            practiceStage(expanded: false)
        }
    }

    private var verticalPath: some View {
        VStack(alignment: .leading, spacing: 7) {
            deepLessonButton(expanded: true)
            connector(systemImage: "arrow.down")
                .padding(.leading, 18)
            modifyButton(expanded: true)
            connector(systemImage: "arrow.down")
                .padding(.leading, 18)
            practiceStage(expanded: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deepLessonButton(expanded: Bool) -> some View {
        Button(action: onOpenDeepLesson) {
            stageLabel(
                title: "Deep Lesson",
                status: deepLessonComplete ? "Viewed" : "Not viewed",
                isComplete: deepLessonComplete,
                isCurrent: false,
                expanded: expanded
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Deep Lesson, \(deepLessonComplete ? "Viewed" : "Not viewed")"
        )
        .accessibilityHint("Open or replay the concept-first Deep Lesson")
        .help("Open or replay the concept-first Deep Lesson")
    }

    private func modifyButton(expanded: Bool) -> some View {
        Button(action: onOpenModify) {
            stageLabel(
                title: "Modify",
                status: modifyComplete ? "Passed" : "Not passed",
                isComplete: modifyComplete,
                isCurrent: false,
                expanded: expanded
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Modify, \(modifyComplete ? "Passed" : "Not passed")"
        )
        .accessibilityHint("Open or replay the guided code modification task")
        .help("Open or replay the guided code modification task")
    }

    private func practiceStage(expanded: Bool) -> some View {
        stageLabel(
            title: "Practice & Run",
            status: practiceComplete ? "Complete · Current workspace" : "Current workspace",
            isComplete: practiceComplete,
            isCurrent: true,
            expanded: expanded
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            practiceComplete
                ? "Practice and Run, Complete, current workspace"
                : "Practice and Run, current workspace"
        )
    }

    private func stageLabel(
        title: String,
        status: String,
        isComplete: Bool,
        isCurrent: Bool,
        expanded: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isComplete ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(expanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: expanded)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(expanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: expanded)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .frame(maxWidth: expanded ? .infinity : nil, alignment: .leading)
        .background(
            isCurrent
                ? Color.accentColor.opacity(0.12)
                : Color.primary.opacity(0.045)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isCurrent
                        ? Color.accentColor.opacity(0.65)
                        : Color.secondary.opacity(0.22),
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
    }

    private func connector(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }
}
