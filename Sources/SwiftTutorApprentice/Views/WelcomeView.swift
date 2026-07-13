// WelcomeView.swift
// ------------------------------------------------------------
// The first-run welcome. Shown once (tracked in AppSettings), it
// explains what the app is and walks through the learning loop so
// a brand-new learner knows what to do.
// ------------------------------------------------------------

import AppKit
import SwiftUI

struct WelcomeRuntimeSnapshotMarker: NSViewRepresentable {
    let copyText: String

    func makeNSView(context: Context) -> WelcomeRuntimeSnapshotView {
        WelcomeRuntimeSnapshotView(copyText: copyText)
    }

    func updateNSView(_ nsView: WelcomeRuntimeSnapshotView, context: Context) {
        nsView.copyText = copyText
        nsView.identifier = NSUserInterfaceItemIdentifier("welcome-copy-snapshot")
    }
}

final class WelcomeRuntimeSnapshotView: NSView {
    var copyText: String

    init(copyText: String) {
        self.copyText = copyText
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("welcome-copy-snapshot")
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct WelcomeStepsRuntimeProbe: NSViewRepresentable {
    func makeNSView(context: Context) -> WelcomeStepsRuntimeProbeView {
        WelcomeStepsRuntimeProbeView()
    }

    func updateNSView(_ nsView: WelcomeStepsRuntimeProbeView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier("welcome-steps-probe")
    }
}

final class WelcomeStepsRuntimeProbeView: NSView {
    init() {
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("welcome-steps-probe")
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct WelcomeView: View {
    let onStart: () -> Void

    private struct Step: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let steps: [Step] = [
        Step(icon: "play.rectangle", title: "Watch",
             detail: "Begin with the lesson's offline animated explanation and persistent captions."),
        Step(icon: "brain.head.profile", title: "Recall",
             detail: "Answer a short question in your own head before the app reveals the explanation."),
        Step(icon: "keyboard", title: "Modify",
             detail: "Change the example yourself so you can see which parts control the result."),
        Step(icon: "play.circle", title: "Practice/Run",
             detail: "Type and run Swift locally, then compare your prediction with the actual output.")
    ]

    private let introduction = "No experience is required. Start in Course Home, choose a path, and learn one small step at a time."
    private let learningLoop = "Watch → Recall → Modify → Practice/Run"
    private let privacyNote = "Lessons work offline and execute locally on this Mac. Your progress stays private in a local file."
    private let footerNote = "Course Home is your starting point."
    private let actionTitle = "Explore courses"

    private var runtimeCopy: String {
        ([
            "Welcome to SwiftTutor Apprentice",
            introduction,
            learningLoop,
            privacyNote,
            footerNote,
            actionTitle
        ] + steps.flatMap { [$0.title, $0.detail] })
            .joined(separator: "\n")
    }

    var body: some View {
        let startCommand = RuntimeNavigationCommand(
            identifier: "welcome-action-command",
            action: onStart
        )

        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "swift")
                    .font(.system(size: 38))
                    .foregroundStyle(.orange)
                Text("Welcome to SwiftTutor Apprentice")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(introduction)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 20)
            .padding(.horizontal, 32)

            Text(learningLoop)
                .font(.headline)
                .padding(.top, 12)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 14) {
                    WelcomeStepsRuntimeProbe()
                        .frame(height: 1)

                    ForEach(steps) { step in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: step.icon)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title).font(.headline)
                                Text(step.detail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Label(
                        privacyNote,
                        systemImage: "lock.fill"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)

            Divider()

            HStack {
                Text(footerNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: startCommand.invoke) {
                    Text(actionTitle)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .background {
                    ZStack {
                        RuntimeViewMarker(identifier: "welcome-action")
                        RuntimeNavigationActionMarker(command: startCommand)
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 560, height: 500)
        .background {
            ZStack {
                RuntimeViewMarker(identifier: "welcome-sheet")
                WelcomeRuntimeSnapshotMarker(copyText: runtimeCopy)
            }
        }
    }
}
