import AppKit
import SwiftUI

private struct PresentationRoundedBoundaryMarker: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = PresentationRoundedBoundaryNSView()
        view.identifier = NSUserInterfaceItemIdentifier("presentation-rounded-boundary")
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier("presentation-rounded-boundary")
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.cornerCurve = .continuous
        nsView.layer?.masksToBounds = true
    }
}

private final class PresentationRoundedBoundaryNSView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct LessonPresentationUnavailablePlayer: View {
    let showsReadDeeper: Bool
    let onReadDeeper: () -> Void

    private let cornerRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.slash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Animated lesson unavailable")
                    .font(.headline)
                Text("This presentation was created by a newer app version. The lesson and practice workspace are still available.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if showsReadDeeper {
                Button("Read deeper", action: onReadDeeper)
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .background {
            RuntimeViewMarker(identifier: "presentation-playback-surface")
        }
        .background {
            RuntimeViewMarker(identifier: "presentation-player-frame")
        }
        .background {
            PresentationRoundedBoundaryMarker(cornerRadius: cornerRadius)
        }
        .background(
            Color.accentColor.opacity(0.045),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.accentColor.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct LessonPresentationPlayer: View {
    private static let boundaryCornerRadius: CGFloat = 14

    private enum PlayerFocus: Hashable {
        case primary
        case back
        case next
        case replay
        case skip
        case narration
        case transcriptToggle
        case transcriptClose
        case readDeeper
    }

    @ObservedObject var controller: PresentationPlayerController
    let onReadDeeper: () -> Void
    let expansionRequestGeneration: UInt64
    let deactivatesOnDisappear: Bool
    let showsReadDeeper: Bool
    let onExpanded: @MainActor () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded: Bool
    @FocusState private var focusedControl: PlayerFocus?

    @MainActor
    init(
        controller: PresentationPlayerController,
        initiallyExpanded: Bool = false,
        expansionRequestGeneration: UInt64 = 0,
        deactivatesOnDisappear: Bool = true,
        showsReadDeeper: Bool = true,
        onExpanded: @escaping @MainActor () -> Void = {},
        onReadDeeper: (() -> Void)? = nil
    ) {
        self.controller = controller
        self.onReadDeeper = onReadDeeper ?? {}
        self.expansionRequestGeneration = expansionRequestGeneration
        self.deactivatesOnDisappear = deactivatesOnDisappear
        self.showsReadDeeper = showsReadDeeper && onReadDeeper != nil
        self.onExpanded = onExpanded
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    private var playerBoundaryShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: Self.boundaryCornerRadius,
            style: .continuous
        )
    }

    var body: some View {
        ZStack {
            Group {
                switch controller.entryMode {
                case .unavailable:
                    unavailableSummary
                case .expandedPoster:
                    poster
                case .compactResume:
                    if isExpanded {
                        activeScene
                    } else {
                        resumeSummary
                    }
                case .compactSummary(let status):
                    completionSummary(status: status)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RuntimeViewMarker(identifier: "presentation-playback-surface")
        }
        .background {
            RuntimeViewMarker(identifier: "presentation-player-frame")
        }
        .background {
            PresentationRoundedBoundaryMarker(
                cornerRadius: Self.boundaryCornerRadius
            )
        }
        .background(Color.accentColor.opacity(0.045), in: playerBoundaryShape)
        .clipShape(playerBoundaryShape)
        .overlay(
            playerBoundaryShape.stroke(Color.accentColor.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .onChange(of: expansionRequestGeneration) { oldGeneration, newGeneration in
            guard newGeneration != oldGeneration else { return }
            isExpanded = true
            restoreFocus(.primary)
        }
        .onChange(of: controller.entryMode) { oldMode, newMode in
            guard oldMode != newMode else { return }
            if case .compactSummary = newMode {
                restoreFocus(.replay)
            }
        }
        .onDisappear {
            if deactivatesOnDisappear {
                controller.deactivate()
            }
        }
    }

    private var unavailableSummary: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.slash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Animated lesson unavailable")
                .font(.headline)
            Spacer()
            readDeeperButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { controlsMarker }
    }

    private var poster: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ANIMATED LESSON")
                            .font(.caption.bold())
                            .foregroundStyle(Color.accentColor)
                        Text(controller.presentation.title)
                            .font(.title2.bold())
                        Text(controller.presentation.posterDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "play.rectangle.on.rectangle")
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        Text(controller.presentation.posterState.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                }

                ViewThatFits(in: .horizontal) {
                    posterControls(compact: false)
                    posterControls(compact: true)
                }
            }
            if controller.showsTranscript {
                transcript
                    .frame(maxWidth: .infinity, maxHeight: 90)
            }
        }
        .padding(18)
    }

    private func posterControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            Button {
                startPresentation()
            } label: {
                compact ? AnyView(Image(systemName: "play.fill")) : AnyView(Text("Start"))
            }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .help("Start the offline animated lesson")
                .accessibilityLabel("Start presentation")
                .focused($focusedControl, equals: .primary)
                .background { actionMarker("presentation-action-start", action: startPresentation) }

            Button {
                skipPresentation()
            } label: {
                compact ? AnyView(Image(systemName: "forward.end")) : AnyView(Text("Skip"))
            }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .help("Skip the presentation and continue to the lesson")
                    .accessibilityLabel("Skip presentation")
                    .focused($focusedControl, equals: .skip)
                    .background { actionMarker("presentation-action-skip", action: skipPresentation) }

            transcriptButton(compact: compact)
            readDeeperButton
        }
        .background { controlsMarker }
    }

    private var resumeSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if controller.showsTranscript {
                transcript
                    .frame(maxWidth: .infinity, maxHeight: 90)
            }

            HStack(alignment: .top, spacing: 12) {
                if let scene = controller.currentScene {
                    PresentationSceneVisual(scene: scene, phase: .before)
                        .frame(width: 112, height: 72)
                        .clipped()
                        .background {
                            ZStack {
                                RuntimeViewMarker(identifier: "presentation-resume-scene-visual")
                                RuntimeViewMarker(identifier: "presentation-resume-scene-\(scene.id)")
                            }
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(controller.presentation.title)
                            .font(.headline)
                        Text(scene.caption)
                            .font(.caption.weight(.medium))
                            .lineLimit(2)
                            .background {
                                ZStack {
                                    RuntimeViewMarker(identifier: "presentation-resume-scene-caption")
                                    RuntimeViewMarker(identifier: "presentation-resume-caption-\(scene.id)")
                                }
                            }
                            .accessibilityLabel("Caption: \(scene.caption)")
                        Text(scene.staticDescription)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .accessibilityLabel("Static description: \(scene.staticDescription)")
                    }
                } else {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(controller.presentation.title)
                            .font(.headline)
                        Text(controller.presentation.posterDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Text(controller.presentation.posterState.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                resumeControls(compact: false)
                resumeControls(compact: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func resumeControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            Button("Resume", action: resumePresentation)
                .keyboardShortcut(.return, modifiers: [])
                .help("Expand the presentation at your saved scene")
                .accessibilityLabel("Resume presentation")
                .focused($focusedControl, equals: .primary)
                .background { actionMarker("presentation-action-resume", action: resumePresentation) }
            replayButton(compact: compact)
            transcriptButton(compact: compact)
            readDeeperButton
        }
        .background { controlsMarker }
    }

    private func completionSummary(status: PresentationStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if controller.showsTranscript {
                transcript
                    .frame(maxWidth: .infinity, maxHeight: 90)
            }
            HStack(spacing: 12) {
                Image(systemName: status == .completed ? "checkmark.circle.fill" : "forward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(status == .completed ? Color.green : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(controller.presentation.title)
                        .font(.headline)
                    Text(status == .completed ? "Animated lesson complete" : "Animated lesson skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            ViewThatFits(in: .horizontal) {
                completionControls(compact: false)
                completionControls(compact: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func completionControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 6 : 10) {
            replayButton(compact: compact)
            transcriptButton(compact: compact)
            readDeeperButton
        }
        .background { controlsMarker }
    }

    private var activeScene: some View {
        ZStack(alignment: .top) {
            ViewThatFits(in: .vertical) {
                activeSceneContent(showsDetails: true)
                activeSceneContent(showsDetails: false)
            }

            if controller.showsTranscript {
                transcript
                    .frame(maxWidth: .infinity, maxHeight: 112)
                    .padding(.top, 44)
            }
        }
        .padding(12)
        .background {
            RuntimeViewMarker(identifier: "presentation-active-scene")
        }
        .accessibilityRepresentation {
            activeAccessibilityRepresentation
        }
    }

    private func activeSceneContent(showsDetails: Bool) -> some View {
        VStack(alignment: .leading, spacing: showsDetails ? 10 : 7) {
            activeHeader
            if let scene = controller.currentScene {
                PresentationSceneVisual(scene: scene, phase: controller.visualPhase)
                    .frame(maxHeight: showsDetails ? 176 : 128)
                    .clipped()
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.28),
                        value: controller.visualPhase
                    )

                Text(scene.caption)
                    .font(.callout.weight(.medium))
                    .lineLimit(showsDetails ? 2 : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RuntimeViewMarker(identifier: "presentation-scene-caption")
                    }
                    .accessibilityLabel("Caption: \(scene.caption)")

                if showsDetails {
                    Text(scene.staticDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Static description: \(scene.staticDescription)")
                }
            }
            activeControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var activeAccessibilityRepresentation: some View {
        VStack {
            Text(sceneCountText)
                .accessibilityLabel(sceneCountText)
            Text(controller.isPlaying ? "Playing" : "Paused")
                .accessibilityLabel("Playback state")
                .accessibilityValue(controller.isPlaying ? "Playing" : "Paused")
            if let scene = controller.currentScene {
                Text(activeSceneAccessibilitySummary(scene))
                    .accessibilityLabel(activeSceneAccessibilitySummary(scene))
                Text(scene.caption)
                    .accessibilityLabel("Caption: \(scene.caption)")
                Text(scene.staticDescription)
                    .accessibilityLabel("Static description: \(scene.staticDescription)")
            }
            Button("Back one scene", action: backPresentation)
            Button("Next scene", action: nextPresentation)
            Button(
                controller.isPlaying ? "Pause presentation" : "Play presentation",
                action: togglePlayback
            )
            Button("Replay presentation", action: replayPresentation)
            Button("Skip presentation", action: skipPresentation)
            Button(
                controller.narrationEnabled ? "Turn narration off" : "Turn narration on",
                action: toggleNarration
            )
            Button(
                controller.showsTranscript ? "Hide transcript" : "Show transcript",
                action: toggleTranscriptFromTransport
            )
            if controller.showsTranscript {
                Text(controller.presentation.transcript)
                    .accessibilityLabel("Transcript: \(controller.presentation.transcript)")
            }
            if showsReadDeeper {
                Button("Read deeper", action: openReadDeeper)
            }
        }
    }

    private var activeHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(controller.currentScene?.title ?? controller.presentation.title)
                    .font(.headline)
                Text(sceneCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(sceneCountText)
            }
            Spacer()
            Text(controller.isPlaying ? "Playing" : "Paused")
                .font(.caption.bold())
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
                .accessibilityLabel("Playback state")
                .accessibilityValue(controller.isPlaying ? "Playing" : "Paused")
        }
    }

    private var activeControls: some View {
        ViewThatFits(in: .horizontal) {
            activeControlRow(compact: false)
            activeControlRow(compact: true)
        }
    }

    private func activeControlRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 5 : 8) {
            Button {
                backPresentation()
            } label: {
                controlLabel("Back", symbol: "backward.end", compact: compact)
            }
                .keyboardShortcut(.leftArrow, modifiers: [.command])
                .help("Go back one presentation scene")
                .accessibilityLabel("Back one scene")
                .focused($focusedControl, equals: .back)
                .background { actionMarker("presentation-action-back", action: backPresentation) }

            Button {
                nextPresentation()
            } label: {
                controlLabel("Next", symbol: "forward.end", compact: compact)
            }
                .keyboardShortcut(.rightArrow, modifiers: [.command])
                .help("Go to the next presentation scene")
                .accessibilityLabel("Next scene")
                .focused($focusedControl, equals: .next)
                .background { actionMarker("presentation-action-next", action: nextPresentation) }

            Button {
                togglePlayback()
            } label: {
                controlLabel(
                    controller.isPlaying ? "Pause" : "Play",
                    symbol: controller.isPlaying ? "pause.fill" : "play.fill",
                    compact: compact
                )
            }
            .buttonStyle(.borderedProminent)
            .help(controller.isPlaying ? "Pause scene playback" : "Play this scene")
            .accessibilityLabel(
                controller.isPlaying ? "Pause presentation" : "Play presentation"
            )
            .focused($focusedControl, equals: .primary)
            .background {
                actionMarker("presentation-action-play-pause", action: togglePlayback)
            }

            replayButton(compact: compact)

            Button {
                skipPresentation()
            } label: {
                controlLabel("Skip", symbol: "forward.end", compact: compact)
            }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .help("Skip the presentation and continue to the lesson")
                .accessibilityLabel("Skip presentation")
                .focused($focusedControl, equals: .skip)
                .background { actionMarker("presentation-action-skip", action: skipPresentation) }

            Button {
                toggleNarration()
            } label: {
                controlLabel(
                    controller.narrationEnabled ? "Narration on" : "Narration off",
                    symbol: controller.narrationEnabled ? "speaker.wave.2" : "speaker.slash",
                    compact: compact
                )
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .help("Toggle fully offline spoken narration")
            .accessibilityLabel(
                controller.narrationEnabled ? "Turn narration off" : "Turn narration on"
            )
            .focused($focusedControl, equals: .narration)
            .background { actionMarker("presentation-action-narration", action: toggleNarration) }

            transcriptButton(compact: compact)
            readDeeperButton
        }
        .controlSize(.small)
        .fixedSize(horizontal: false, vertical: true)
        .background { controlsMarker }
    }

    private func replayButton(compact: Bool) -> some View {
        Button {
            replayPresentation()
        } label: {
            controlLabel("Replay", symbol: "arrow.counterclockwise", compact: compact)
        }
        .keyboardShortcut("r", modifiers: [.command, .shift])
        .help("Replay from the first scene")
        .accessibilityLabel("Replay presentation")
        .focused($focusedControl, equals: .replay)
        .background { actionMarker("presentation-action-replay", action: replayPresentation) }
    }

    private func transcriptButton(compact: Bool = false) -> some View {
        Button {
            toggleTranscriptFromTransport()
        } label: {
            controlLabel(
                controller.showsTranscript ? "Hide transcript" : "Transcript",
                symbol: "text.alignleft",
                compact: compact
            )
        }
        .keyboardShortcut("t", modifiers: [.command, .shift])
        .help(controller.showsTranscript ? "Hide the transcript" : "Show the transcript")
        .accessibilityLabel(
            controller.showsTranscript ? "Hide transcript" : "Show transcript"
        )
        .focused($focusedControl, equals: .transcriptToggle)
        .background {
            ZStack {
                actionMarker(
                    "presentation-action-transcript",
                    action: toggleTranscriptFromTransport
                )
                RuntimeViewMarker(
                    identifier: "presentation-focus-transcript-toggle"
                )
            }
        }
    }

    @ViewBuilder
    private var readDeeperButton: some View {
        if showsReadDeeper {
            Button("Read deeper", action: openReadDeeper)
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .help("Open the detailed concept lesson")
                .accessibilityLabel("Read deeper")
                .focused($focusedControl, equals: .readDeeper)
                .background {
                    actionMarker("presentation-action-read-deeper", action: openReadDeeper)
                }
        }
    }

    @ViewBuilder
    private func controlLabel(
        _ title: String,
        symbol: String,
        compact: Bool
    ) -> some View {
        if compact {
            Image(systemName: symbol)
        } else {
            Text(title)
        }
    }

    private var controlsMarker: some View {
        RuntimeViewMarker(identifier: "presentation-controls")
    }

    private func actionMarker(
        _ identifier: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        RuntimeNavigationActionMarker(
            command: RuntimeNavigationCommand(
                identifier: identifier,
                action: action
            )
        )
    }

    private func startPresentation() {
        expandPlayer()
        controller.start()
        restoreFocus(.primary)
    }

    private func resumePresentation() {
        expandPlayer()
        restoreFocus(.primary)
    }

    private func togglePlayback() {
        controller.isPlaying ? controller.pause() : controller.play()
        restoreFocus(.primary)
    }

    private func backPresentation() {
        controller.back()
        restoreFocus(.back)
    }

    private func nextPresentation() {
        controller.next()
        if case .compactSummary = controller.entryMode {
            restoreFocus(.replay)
        } else {
            restoreFocus(.next)
        }
    }

    private func replayPresentation() {
        expandPlayer()
        controller.replay()
        restoreFocus(.primary)
    }

    private func skipPresentation() {
        controller.skip()
        restoreFocus(.replay)
    }

    private func expandPlayer() {
        isExpanded = true
        onExpanded()
    }

    private func toggleNarration() {
        controller.toggleNarration()
        restoreFocus(.narration)
    }

    private func toggleTranscriptFromTransport() {
        toggleTranscript(returningFocusTo: .transcriptToggle)
    }

    private func hideTranscriptFromOverlay() {
        toggleTranscript(returningFocusTo: .transcriptToggle)
    }

    private func toggleTranscript(returningFocusTo focus: PlayerFocus) {
        controller.toggleTranscript()
        restoreFocus(focus)
    }

    private func openReadDeeper() {
        onReadDeeper()
    }

    private func restoreFocus(_ focus: PlayerFocus) {
        focusedControl = nil
        DispatchQueue.main.async {
            focusedControl = focus
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Transcript")
                    .font(.caption.bold())
                Spacer()
                Button("Hide transcript") {
                    hideTranscriptFromOverlay()
                }
                .controlSize(.small)
                .keyboardShortcut(.escape, modifiers: [])
                .help("Close the transcript and return focus to the transcript control")
                .accessibilityLabel("Hide transcript")
                .focused($focusedControl, equals: .transcriptClose)
                .background {
                    ZStack {
                        actionMarker(
                            "presentation-transcript-close",
                            action: hideTranscriptFromOverlay
                        )
                        RuntimeViewMarker(
                            identifier: "presentation-focus-transcript-close"
                        )
                    }
                }
            }
            ScrollView(.vertical) {
                Text(controller.presentation.transcript)
                    .font(.callout)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .background {
            RuntimeViewMarker(identifier: "presentation-transcript")
        }
        .accessibilityLabel("Transcript")
        .accessibilityValue(controller.presentation.transcript)
        .accessibilityElement(children: .contain)
    }

    private var sceneCountText: String {
        guard let index = controller.currentSceneIndex else {
            return "Scene unavailable"
        }
        return "Scene \(index + 1) of \(controller.presentation.scenes.count)"
    }

    private func activeSceneAccessibilitySummary(_ scene: PresentationScene) -> String {
        let state = controller.visualPhase == .before ? scene.before : scene.after
        let focused = scene.focusTargets.compactMap { target -> String? in
            switch target.kind {
            case .codeToken:
                guard let token = state.codeTokens.first(where: { $0.id == target.id }) else {
                    return nil
                }
                return "Focused code token: \(token.text)"
            case .value:
                guard let value = state.values.first(where: { $0.id == target.id }) else {
                    return nil
                }
                return "Focused value: \(value.name) equals \(value.value)"
            case .output:
                guard state.outputTargetID == target.id,
                      let output = state.output else { return nil }
                return "Focused output: \(output)"
            }
        }
        return (focused + ["Result: \(state.description)"]).joined(separator: ". ")
    }
}
