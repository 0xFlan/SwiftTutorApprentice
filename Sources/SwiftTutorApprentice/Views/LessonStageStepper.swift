// LessonStageStepper.swift
// ------------------------------------------------------------
// A compact, non-locking guide to the recommended learning path.
// Watch and Modify remain replayable at every stage; Read deeper
// stays in player chrome and the workspace remains available.
// ------------------------------------------------------------

import SwiftUI

struct LessonStageStepper: View {
    static let orderedStageTitles = ["Watch", "Recall", "Modify", "Practice/Run"]

    let watchStatus: String
    let recallStatus: String
    let modifyComplete: Bool
    let practiceComplete: Bool
    let onOpenWatch: () -> Void
    let onOpenRecall: () -> Void
    let onOpenModify: () -> Void
    var watchEnabled = true
    var recallEnabled = true
    var modifyEnabled = true

    var body: some View {
        // A vertical ViewThatFits fallback can publish an oversized intrinsic
        // height while NavigationSplitView is measuring a narrow proposal.
        // Keep one bounded row and let genuinely narrow windows scroll it.
        ScrollView(.horizontal) {
            horizontalPath
                .fixedSize(horizontal: true, vertical: false)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.accentColor.opacity(0.055)
            RuntimeViewMarker(identifier: "lesson-stage-path")
        }
        .accessibilityElement(children: .contain)
    }

    private var horizontalPath: some View {
        HStack(spacing: 10) {
            watchButton(expanded: false)
            connector(systemImage: "arrow.right")
            recallButton(expanded: false)
            connector(systemImage: "arrow.right")
            modifyButton(expanded: false)
            connector(systemImage: "arrow.right")
            practiceStage(expanded: false)
        }
    }

    private func watchButton(expanded: Bool) -> some View {
        Button(action: onOpenWatch) {
            stageLabel(
                title: Self.orderedStageTitles[0],
                status: watchStatus,
                isComplete: watchStatus == "Complete",
                isCurrent: false,
                expanded: expanded
            )
        }
        .buttonStyle(.plain)
        .disabled(!watchEnabled)
        .background {
            if !watchEnabled {
                RuntimeViewMarker(identifier: "lesson-stage-watch-disabled")
            }
            if watchStatus == "Unavailable" {
                RuntimeViewMarker(identifier: "lesson-stage-watch-unavailable")
            }
        }
        .accessibilityLabel("Watch, \(watchStatus)")
        .accessibilityHint(
            watchEnabled
                ? "Resume or replay the animated lesson"
                : "The animated lesson is unavailable in this app version"
        )
        .help(
            watchEnabled
                ? "Resume or replay the animated lesson"
                : "Animated lesson unavailable"
        )
    }

    private func recallButton(expanded: Bool) -> some View {
        Button(action: onOpenRecall) {
            stageLabel(
                title: Self.orderedStageTitles[1],
                status: recallDisplayStatus,
                isComplete: recallDisplayStatus == "Answered",
                isCurrent: false,
                expanded: expanded
            )
        }
        .buttonStyle(.plain)
        .disabled(!recallEnabled)
        .background {
            if recallEnabled {
                RuntimeNavigationActionMarker(
                    command: RuntimeNavigationCommand(
                        identifier: "lesson-stage-recall-enabled",
                        action: onOpenRecall
                    )
                )
            }
            RuntimeViewMarker(identifier: recallStatusIdentifier)
        }
        .accessibilityLabel("Recall, \(recallDisplayStatus)")
        .accessibilityHint(
            recallEnabled ? "Move to the linked Recall prompt" : "Recall unavailable"
        )
        .help(recallEnabled ? "Move to the linked Recall prompt" : "Recall unavailable")
    }

    private func modifyButton(expanded: Bool) -> some View {
        Button(action: onOpenModify) {
            stageLabel(
                title: Self.orderedStageTitles[2],
                status: modifyDisplayStatus,
                isComplete: modifyEnabled && modifyComplete,
                isCurrent: false,
                expanded: expanded
            )
        }
        .buttonStyle(.plain)
        .disabled(!modifyEnabled)
        .background {
            if modifyEnabled {
                RuntimeViewMarker(identifier: "lesson-stage-modify-enabled")
            }
            RuntimeViewMarker(identifier: modifyStatusIdentifier)
        }
        .accessibilityLabel("Modify, \(modifyDisplayStatus)")
        .accessibilityHint(
            modifyEnabled
                ? "Open or replay the guided code modification task"
                : "Modify unavailable"
        )
        .help(
            modifyEnabled
                ? "Open or replay the guided code modification task"
                : "Modify unavailable"
        )
    }

    private func practiceStage(expanded: Bool) -> some View {
        stageLabel(
            title: Self.orderedStageTitles[3],
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

    private var recallDisplayStatus: String {
        recallEnabled ? recallStatus : "Unavailable"
    }

    private var modifyDisplayStatus: String {
        guard modifyEnabled else { return "Unavailable" }
        return modifyComplete ? "Passed" : "Not passed"
    }

    private var recallStatusIdentifier: String {
        switch recallDisplayStatus {
        case "Answered": return "lesson-stage-recall-answered"
        case "Not answered": return "lesson-stage-recall-not-answered"
        default: return "lesson-stage-recall-unavailable"
        }
    }

    private var modifyStatusIdentifier: String {
        switch modifyDisplayStatus {
        case "Passed": return "lesson-stage-modify-passed"
        case "Not passed": return "lesson-stage-modify-not-passed"
        default: return "lesson-stage-modify-unavailable"
        }
    }
}
