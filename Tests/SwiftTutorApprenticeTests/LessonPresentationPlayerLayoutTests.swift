import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

final class LessonPresentationPlayerLayoutTests: XCTestCase {
    @MainActor private static var retainedHostedWindows: [NSWindow] = []

    @MainActor
    func testWorkspaceEnvironmentUpdatesTheActiveSessionReduceMotionValue() throws {
        let session = LessonWorkspaceSession(waitForAdvance: {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        })
        let host = NSHostingView(
            rootView: WorkspaceReduceMotionHarness(
                session: session,
                reduceMotion: false
            )
        )
        host.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        session.activate(
            for: .swift(1),
            presentation: SwiftPilotPresentationContent.lesson1,
            savedState: nil,
            persist: { _, _ in }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.start()
        controller.play()
        XCTAssertEqual(controller.visualPhase, .before)
        controller.pause()

        host.rootView = WorkspaceReduceMotionHarness(
            session: session,
            reduceMotion: true
        )
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        controller.play()

        XCTAssertEqual(
            controller.visualPhase,
            .after,
            "Changing the system environment must affect the existing controller."
        )
        controller.pause()
    }

    @MainActor
    func testWatchExpansionKeepsTheOwnedPlayingControllerAlive() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let saved = LessonPresentationState(
            status: .started,
            lastSceneID: presentation.scenes[1].id,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 0
        )
        let session = LessonWorkspaceSession(waitForAdvance: {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        })
        session.activate(
            for: .swift(3),
            presentation: presentation,
            savedState: saved,
            persist: { _, _ in }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.play()
        XCTAssertTrue(controller.isPlaying)

        let host = NSHostingView(
            rootView: WorkspacePlayerExpansionHarness(session: session)
                .frame(width: 680, height: 620)
        )
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 620)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(markers(named: "presentation-active-scene", in: host).isEmpty)

        session.openWatch()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertTrue(controller === session.controller)
        XCTAssertTrue(
            controller.isPlaying,
            "Expanding Watch must not remove a child that deactivates the shared controller."
        )
        XCTAssertEqual(
            markers(named: "presentation-active-scene", in: host).count,
            1
        )
        controller.pause()
    }

    @MainActor
    func testReadDeeperActionAvailabilityAcrossEveryRenderedPlayerSurface() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let started = presentationState(
            status: .started,
            sceneID: presentation.scenes[1].id,
            presentation: presentation
        )
        let states: [(String, LessonPresentationState?, Bool)] = [
            ("poster", nil, false),
            ("resume", started, false),
            ("active", started, true),
            (
                "skipped",
                presentationState(status: .skipped, sceneID: nil, presentation: presentation),
                false
            ),
            (
                "completed",
                presentationState(
                    status: .completed,
                    sceneID: presentation.scenes.last?.id,
                    presentation: presentation
                ),
                false
            )
        ]

        for showsReadDeeper in [false, true] {
            for (name, state, expanded) in states {
                var callbackCount = 0
                let rendered = try renderPlayer(
                    name: name,
                    controller: Self.makeController(presentation: presentation, savedState: state),
                    width: 680,
                    initiallyExpanded: expanded,
                    showsReadDeeper: showsReadDeeper,
                    onReadDeeper: { callbackCount += 1 }
                )
                defer { retainAndClose(rendered) }
                let actions = markers(named: "presentation-action-read-deeper", in: rendered.host)
                XCTAssertEqual(actions.count, showsReadDeeper ? 1 : 0, name)
                if showsReadDeeper {
                    try invokeAction("presentation-action-read-deeper", in: rendered.host)
                    XCTAssertEqual(callbackCount, 1, name)
                } else {
                    XCTAssertEqual(callbackCount, 0, name)
                }
            }

            var unavailableCallbackCount = 0
            let unavailable = try renderPlayer(
                name: "unavailable",
                controller: Self.makeController(
                    presentation: unavailablePresentation(from: presentation)
                ),
                width: 680,
                showsReadDeeper: showsReadDeeper,
                onReadDeeper: { unavailableCallbackCount += 1 }
            )
            defer { retainAndClose(unavailable) }
            XCTAssertEqual(
                markers(named: "presentation-action-read-deeper", in: unavailable.host).count,
                showsReadDeeper ? 1 : 0
            )
            if showsReadDeeper {
                try invokeAction("presentation-action-read-deeper", in: unavailable.host)
                XCTAssertEqual(unavailableCallbackCount, 1)
            } else {
                XCTAssertEqual(unavailableCallbackCount, 0)
            }
        }
    }

    @MainActor
    func testEveryPlayerStateUsesTheSameExactSixteenByNineFrame() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        for width in [CGFloat(480), CGFloat(680)] {
            let renderings = try playerStateRenderings(
                presentation: presentation,
                width: width
            )
            defer { renderings.forEach(retainAndClose) }

            let frames = try renderings.map { rendering -> NSRect in
                let marker = try XCTUnwrap(
                    markers(named: "presentation-player-frame", in: rendering.host).first,
                    "Missing media-frame marker for \(rendering.name)"
                )
                return marker.convert(marker.bounds, to: rendering.host)
            }
            let reference = try XCTUnwrap(frames.first)

            for (index, frame) in frames.enumerated() {
                XCTAssertEqual(frame.width, width, accuracy: 1, renderings[index].name)
                XCTAssertEqual(
                    frame.width / frame.height,
                    16.0 / 9.0,
                    accuracy: 0.02,
                    renderings[index].name
                )
                XCTAssertEqual(frame.width, reference.width, accuracy: 1, renderings[index].name)
                XCTAssertEqual(frame.height, reference.height, accuracy: 1, renderings[index].name)

                let containedMarkers = markers(
                    named: "presentation-controls",
                    in: renderings[index].host
                ) + markers(
                    named: "presentation-transcript",
                    in: renderings[index].host
                )
                for contained in containedMarkers {
                    let rect = contained.convert(contained.bounds, to: renderings[index].host)
                    XCTAssertTrue(
                        frame.insetBy(dx: -1, dy: -1).contains(rect),
                        "\(contained.identifier?.rawValue ?? "marker") escaped \(renderings[index].name): \(rect) outside \(frame)"
                    )
                }
            }
        }
    }

    @MainActor
    func testFirstVisitPosterTranscriptStaysInsideThePlayerFrame() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        var writes = 0
        let trackedController = PresentationPlayerController(
            lessonKey: .swift(3),
            presentation: presentation,
            savedState: nil,
            persist: { _, _ in writes += 1 },
            waitForAdvance: {},
            narrator: UnavailableNarrator()
        )
        let hostingView = NSHostingView(
            rootView: LessonPresentationPlayer(controller: trackedController)
                .frame(width: 680)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 340),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFrontRegardless()
        defer {
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        try invokeAction("presentation-action-transcript", in: hostingView)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        XCTAssertTrue(trackedController.showsTranscript)
        XCTAssertEqual(writes, 0)
        let revealed = accessibilityStrings(in: hostingView).joined(separator: " | ")
        if revealed.isEmpty == false {
            XCTAssertTrue(revealed.contains("Transcript"))
            XCTAssertTrue(revealed.contains(presentation.transcript))
        }
        let transcriptViews = markers(named: "presentation-transcript", in: hostingView)
        XCTAssertEqual(transcriptViews.count, 1)
        let playerFrame = try XCTUnwrap(
            markers(named: "presentation-player-frame", in: hostingView).first
        )
        let playerRect = playerFrame.convert(playerFrame.bounds, to: hostingView)
        let transcriptRect = transcriptViews[0].convert(transcriptViews[0].bounds, to: hostingView)
        XCTAssertTrue(playerRect.insetBy(dx: -1, dy: -1).contains(transcriptRect))

        try invokeAction("presentation-action-transcript", in: hostingView)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(trackedController.showsTranscript)
        XCTAssertTrue(markers(named: "presentation-transcript", in: hostingView).isEmpty)
        XCTAssertEqual(writes, 0)
    }

    @MainActor
    func testTranscriptOverlayHasAContainedReachableCloseControl() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(
            presentation: presentation,
            savedState: presentationState(
                status: .started,
                sceneID: presentation.scenes[1].id,
                presentation: presentation
            )
        )
        controller.toggleTranscript()
        let rendered = try renderPlayer(
            name: "transcript-close",
            controller: controller,
            width: 480,
            initiallyExpanded: true
        )
        defer { retainAndClose(rendered) }

        let player = try XCTUnwrap(
            markers(named: "presentation-player-frame", in: rendered.host).first
        )
        let transcript = try XCTUnwrap(
            markers(named: "presentation-transcript", in: rendered.host).first
        )
        let close = try XCTUnwrap(
            markers(named: "presentation-transcript-close", in: rendered.host).first
                as? RuntimeNavigationActionView
        )
        let playerRect = player.convert(player.bounds, to: rendered.host)
        let transcriptRect = transcript.convert(transcript.bounds, to: rendered.host)
        let closeRect = close.convert(close.bounds, to: rendered.host)
        XCTAssertGreaterThan(closeRect.width, 0)
        XCTAssertGreaterThan(closeRect.height, 0)
        XCTAssertTrue(playerRect.insetBy(dx: -1, dy: -1).contains(closeRect))
        XCTAssertTrue(transcriptRect.insetBy(dx: -1, dy: -1).contains(closeRect))

        let originalFrame = playerRect
        close.invoke()
        settle(rendered.host)
        XCTAssertFalse(controller.showsTranscript)
        XCTAssertEqual(try playerFrame(in: rendered.host).width, originalFrame.width, accuracy: 1)
        XCTAssertEqual(try playerFrame(in: rendered.host).height, originalFrame.height, accuracy: 1)
    }

    @MainActor
    func testCompactActivePlayerKeepsAuthoredCaptionInsideTheFrame() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let rendered = try renderPlayer(
            name: "compact-caption",
            controller: Self.makeController(
                presentation: presentation,
                savedState: presentationState(
                    status: .started,
                    sceneID: presentation.scenes[1].id,
                    presentation: presentation
                )
            ),
            width: 480,
            initiallyExpanded: true
        )
        defer { retainAndClose(rendered) }

        let player = try XCTUnwrap(
            markers(named: "presentation-player-frame", in: rendered.host).first
        )
        let caption = try XCTUnwrap(
            markers(named: "presentation-scene-caption", in: rendered.host).first
        )
        let playerRect = player.convert(player.bounds, to: rendered.host)
        let captionRect = caption.convert(caption.bounds, to: rendered.host)
        XCTAssertGreaterThan(captionRect.width, 0)
        XCTAssertGreaterThan(captionRect.height, 0)
        XCTAssertTrue(playerRect.insetBy(dx: -1, dy: -1).contains(captionRect))
    }

    @MainActor
    func testTranscriptRegionDoesNotCoverTransportControlsAndUsesDistinctFocusTargets() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(
            presentation: presentation,
            savedState: presentationState(
                status: .started,
                sceneID: presentation.scenes[1].id,
                presentation: presentation
            )
        )
        controller.toggleTranscript()
        let rendered = try renderPlayer(
            name: "transcript-focus-layout",
            controller: controller,
            width: 480,
            initiallyExpanded: true
        )
        defer { retainAndClose(rendered) }

        let transcript = try XCTUnwrap(
            markers(named: "presentation-transcript", in: rendered.host).first
        )
        let controls = try XCTUnwrap(
            markers(named: "presentation-controls", in: rendered.host)
                .first(where: { $0.bounds.isEmpty == false })
        )
        let transcriptRect = transcript.convert(transcript.bounds, to: rendered.host)
        let controlsRect = controls.convert(controls.bounds, to: rendered.host)
        XCTAssertFalse(
            transcriptRect.intersects(controlsRect),
            "Transcript \(transcriptRect) must not obscure transport controls \(controlsRect)."
        )

        let transportFocus = try XCTUnwrap(
            markers(named: "presentation-focus-transcript-toggle", in: rendered.host).first
        )
        let closeFocus = try XCTUnwrap(
            markers(named: "presentation-focus-transcript-close", in: rendered.host).first
        )
        XCTAssertFalse(transportFocus === closeFocus)

        try invokeAction("presentation-action-transcript", in: rendered.host)
        settle(rendered.host)
        XCTAssertFalse(controller.showsTranscript)
        try invokeAction("presentation-action-transcript", in: rendered.host)
        settle(rendered.host)
        XCTAssertTrue(controller.showsTranscript)
        try invokeAction("presentation-transcript-close", in: rendered.host)
        settle(rendered.host)
        XCTAssertFalse(controller.showsTranscript)
    }

    @MainActor
    func testPosterTranscriptRegionDoesNotCoverItsTransportControls() throws {
        let controller = Self.makeController(
            presentation: SwiftPilotPresentationContent.lesson3
        )
        controller.toggleTranscript()
        let rendered = try renderPlayer(
            name: "poster-transcript-layout",
            controller: controller,
            width: 480
        )
        defer { retainAndClose(rendered) }

        let transcript = try XCTUnwrap(
            markers(named: "presentation-transcript", in: rendered.host).first
        )
        let controls = try XCTUnwrap(
            markers(named: "presentation-controls", in: rendered.host)
                .first(where: { $0.bounds.isEmpty == false })
        )
        let transcriptRect = transcript.convert(transcript.bounds, to: rendered.host)
        let controlsRect = controls.convert(controls.bounds, to: rendered.host)
        XCTAssertFalse(
            transcriptRect.intersects(controlsRect),
            "Poster transcript \(transcriptRect) must not obscure controls \(controlsRect)."
        )
    }

    @MainActor
    func testRoundedBoundaryRuntimeStructureContainsPlayerRegions() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(
            presentation: presentation,
            savedState: presentationState(
                status: .started,
                sceneID: presentation.scenes[1].id,
                presentation: presentation
            )
        )
        controller.toggleTranscript()
        let rendered = try renderPlayer(
            name: "rounded-boundary",
            controller: controller,
            width: 480,
            initiallyExpanded: true
        )
        defer { retainAndClose(rendered) }

        let frameMarker = try XCTUnwrap(
            markers(named: "presentation-player-frame", in: rendered.host).first
        )
        let frame = frameMarker.convert(frameMarker.bounds, to: rendered.host)
        for identifier in [
            "presentation-active-scene",
            "presentation-transcript",
            "presentation-controls"
        ] {
            for marker in markers(named: identifier, in: rendered.host) {
                let rect = marker.convert(marker.bounds, to: rendered.host)
                XCTAssertTrue(
                    frame.insetBy(dx: -1, dy: -1).contains(rect),
                    "\(identifier) escaped the rounded player boundary."
                )
            }
        }

        let boundary = try XCTUnwrap(
            markers(named: "presentation-rounded-boundary", in: rendered.host).first
        )
        XCTAssertEqual(boundary.layer?.cornerRadius ?? 0, 14, accuracy: 0.01)
        XCTAssertEqual(boundary.layer?.masksToBounds, true)
        XCTAssertNil(
            boundary.hitTest(NSPoint(x: boundary.bounds.midX, y: boundary.bounds.midY)),
            "The structural rounded-boundary marker must not intercept player input."
        )
        XCTAssertEqual(
            boundary.convert(boundary.bounds, to: rendered.host),
            frame
        )
    }

    @MainActor
    func testEveryRenderedProductionActionIsNonzeroAndInsidePlayerFrame() throws {
        let presentation = SwiftPilotPresentationContent.lesson3

        for width in [CGFloat(480), CGFloat(680)] {
            let renderings = try playerStateRenderings(
                presentation: presentation,
                width: width
            )
            defer { renderings.forEach(retainAndClose) }

            for rendering in renderings {
                let frame = try playerFrame(in: rendering.host)
                let actions = actionMarkers(in: rendering.host)
                for action in actions {
                    let identifier = action.identifier?.rawValue ?? "unidentified-action"
                    let rect = action.convert(action.bounds, to: rendering.host)
                    XCTAssertGreaterThan(rect.width, 0, "\(rendering.name): \(identifier)")
                    XCTAssertGreaterThan(rect.height, 0, "\(rendering.name): \(identifier)")
                    XCTAssertTrue(
                        frame.insetBy(dx: -1, dy: -1).contains(rect),
                        "\(rendering.name): \(identifier) \(rect) escaped \(frame)"
                    )
                }
                XCTAssertGreaterThan(actions.count, 0, rendering.name)
            }
        }
    }

    @MainActor
    func testResumeShowsSavedSceneAndCompactSurfacesKeepTranscriptReachable() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let savedScene = presentation.scenes[1]
        let states: [(String, LessonPresentationState)] = [
            (
                "resume",
                presentationState(
                    status: .started,
                    sceneID: savedScene.id,
                    presentation: presentation
                )
            ),
            (
                "skipped",
                presentationState(
                    status: .skipped,
                    sceneID: nil,
                    presentation: presentation
                )
            ),
            (
                "completed",
                presentationState(
                    status: .completed,
                    sceneID: presentation.scenes.last?.id,
                    presentation: presentation
                )
            )
        ]

        for width in [CGFloat(480), CGFloat(680)] {
            for (name, state) in states {
                var writes = 0
                let controller = PresentationPlayerController(
                    lessonKey: .swift(3),
                    presentation: presentation,
                    savedState: state,
                    persist: { _, _ in writes += 1 },
                    waitForAdvance: {},
                    narrator: UnavailableNarrator()
                )
                let rendered = try renderPlayer(name: name, controller: controller, width: width)
                defer { retainAndClose(rendered) }

                if name == "resume" {
                    XCTAssertEqual(
                        markers(named: "presentation-resume-scene-visual", in: rendered.host).count,
                        1
                    )
                    XCTAssertEqual(
                        markers(named: "presentation-resume-scene-caption", in: rendered.host).count,
                        1
                    )
                    XCTAssertEqual(
                        markers(named: "presentation-resume-scene-\(savedScene.id)", in: rendered.host).count,
                        1
                    )
                    XCTAssertEqual(
                        markers(named: "presentation-resume-caption-\(savedScene.id)", in: rendered.host).count,
                        1
                    )
                    XCTAssertEqual(controller.currentCaption, savedScene.caption)
                    XCTAssertEqual(controller.currentStaticDescription, savedScene.staticDescription)
                }

                XCTAssertEqual(
                    markers(named: "presentation-action-transcript", in: rendered.host).count,
                    1,
                    "\(name)-\(Int(width))"
                )
                try invokeAction("presentation-action-transcript", in: rendered.host)
                settle(rendered.host)

                XCTAssertTrue(controller.showsTranscript, name)
                XCTAssertEqual(writes, 0, name)
                let frame = try playerFrame(in: rendered.host)
                let transcript = try XCTUnwrap(
                    markers(named: "presentation-transcript", in: rendered.host).first,
                    name
                )
                let transcriptFrame = transcript.convert(transcript.bounds, to: rendered.host)
                XCTAssertTrue(frame.insetBy(dx: -1, dy: -1).contains(transcriptFrame), name)
                XCTAssertEqual(
                    markers(named: "presentation-transcript-close", in: rendered.host).count,
                    1,
                    name
                )
                for controls in markers(named: "presentation-controls", in: rendered.host) {
                    let controlsFrame = controls.convert(controls.bounds, to: rendered.host)
                    XCTAssertFalse(transcriptFrame.intersects(controlsFrame), name)
                }
            }
        }
    }

    @MainActor
    func testProductionPlayerActionsPreserveOuterScrollAndFrameGeometry() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let startedAtSecondScene = presentationState(
            status: .started,
            sceneID: presentation.scenes[1].id,
            presentation: presentation
        )
        let completed = presentationState(
            status: .completed,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let startedAtFinalScene = presentationState(
            status: .started,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let actions: [PlayerActionScenario] = [
            .init(name: "Start", marker: "presentation-action-start") {
                (Self.makeController(presentation: presentation), false)
            },
            .init(name: "Resume", marker: "presentation-action-resume") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), false)
            },
            .init(name: "Play", marker: "presentation-action-play-pause") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), true)
            },
            .init(name: "Pause", marker: "presentation-action-play-pause") {
                let controller = Self.makeController(
                    presentation: presentation,
                    savedState: startedAtSecondScene
                )
                controller.play()
                return (controller, true)
            },
            .init(name: "Back", marker: "presentation-action-back") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), true)
            },
            .init(name: "Next", marker: "presentation-action-next") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), true)
            },
            .init(name: "Completion", marker: "presentation-action-next") {
                (
                    Self.makeController(
                        presentation: presentation,
                        savedState: startedAtFinalScene
                    ),
                    true
                )
            },
            .init(name: "Replay", marker: "presentation-action-replay") {
                (Self.makeController(presentation: presentation, savedState: completed), false)
            },
            .init(name: "Skip", marker: "presentation-action-skip") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), true)
            },
            .init(name: "Narration", marker: "presentation-action-narration") {
                (
                    Self.makeController(
                        presentation: presentation,
                        savedState: startedAtSecondScene,
                        narrator: AvailableNarrator()
                    ),
                    true
                )
            },
            .init(name: "Transcript", marker: "presentation-action-transcript") {
                (Self.makeController(presentation: presentation, savedState: startedAtSecondScene), true)
            }
        ]

        for scenario in actions {
            let (controller, initiallyExpanded) = scenario.makePlayer()
            let rendered = try renderScrollHarness(
                controller: controller,
                initiallyExpanded: initiallyExpanded
            )
            defer { retainAndClose(rendered) }
            setScrollOffset(240, in: rendered.scrollView)
            let originalY = rendered.scrollView.contentView.bounds.origin.y
            let originalFrame = try playerFrame(in: rendered.host)

            try invokeAction(scenario.marker, in: rendered.host)
            settle(rendered.host)

            let resultingFrame = try playerFrame(in: rendered.host)
            XCTAssertEqual(
                rendered.scrollView.contentView.bounds.origin.y,
                originalY,
                accuracy: 1,
                scenario.name
            )
            XCTAssertEqual(resultingFrame.width, originalFrame.width, accuracy: 1, scenario.name)
            XCTAssertEqual(resultingFrame.height, originalFrame.height, accuracy: 1, scenario.name)
            controller.pause()
        }
    }

    @MainActor
    func testTranscriptRetainsPlayerLocalFocus() throws {
        let focusSupported = hostedSwiftUIFocusIsSupported()
        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(
            presentation: presentation,
            savedState: presentationState(
                status: .started,
                sceneID: presentation.scenes[1].id,
                presentation: presentation
            )
        )
        let rendered = try renderScrollHarness(controller: controller, initiallyExpanded: true)
        defer { retainAndClose(rendered) }

        try invokeAction("presentation-action-transcript", in: rendered.host)
        settle(rendered.host)
        XCTAssertTrue(controller.showsTranscript)
        let shownResponder = rendered.window.firstResponder as? NSView
        if focusSupported {
            assertResponder(
                try XCTUnwrap(shownResponder),
                isInsidePlayerIn: rendered.host
            )
        }

        try invokeAction("presentation-action-transcript", in: rendered.host)
        settle(rendered.host)
        XCTAssertFalse(controller.showsTranscript)
        if focusSupported {
            let hiddenResponder = try XCTUnwrap(rendered.window.firstResponder as? NSView)
            XCTAssertTrue(shownResponder === hiddenResponder, "Transcript toggle must retain focus.")
            assertResponder(hiddenResponder, isInsidePlayerIn: rendered.host)
        } else {
            throw XCTSkip(
                "Known-good SwiftUI @FocusState button exposes no AppKit first responder in this hosted XCTest process."
            )
        }
    }

    @MainActor
    func testReplacementActionsKeepFocusInsideLeafPlayerFrame() throws {
        let focusSupported = hostedSwiftUIFocusIsSupported()
        let presentation = SwiftPilotPresentationContent.lesson3
        let completed = presentationState(
            status: .completed,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let startedAtFinalScene = presentationState(
            status: .started,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let startedAtSecondScene = presentationState(
            status: .started,
            sceneID: presentation.scenes[1].id,
            presentation: presentation
        )
        let scenarios: [(String, PresentationPlayerController, Bool, PresentationStatus)] = [
            (
                "presentation-action-start",
                Self.makeController(presentation: presentation),
                false,
                .started
            ),
            (
                "presentation-action-replay",
                Self.makeController(presentation: presentation, savedState: completed),
                false,
                .started
            ),
            (
                "presentation-action-skip",
                Self.makeController(presentation: presentation, savedState: startedAtSecondScene),
                true,
                .skipped
            ),
            (
                "presentation-action-next",
                Self.makeController(presentation: presentation, savedState: startedAtFinalScene),
                true,
                .completed
            )
        ]

        for (marker, controller, initiallyExpanded, expectedStatus) in scenarios {
            let rendered = try renderScrollHarness(
                controller: controller,
                initiallyExpanded: initiallyExpanded
            )
            defer { retainAndClose(rendered) }
            try invokeAction(marker, in: rendered.host)
            settle(rendered.host)
            XCTAssertEqual(controller.entryMode, expectedEntryMode(expectedStatus, presentation: presentation))

            if focusSupported {
                let responder = try XCTUnwrap(
                    rendered.window.firstResponder as? NSView,
                    "\(marker) did not restore a local first responder"
                )
                assertResponder(responder, isInsidePlayerIn: rendered.host)
            }
        }
        if focusSupported == false {
            throw XCTSkip(
                "Known-good SwiftUI @FocusState button exposes no AppKit first responder in this hosted XCTest process."
            )
        }
    }

    @MainActor
    func testWheelScrollStillWorksWhilePlaybackNarrationIsSuspended() throws {
        let rendered = try narratedPlayingScrollHarness()
        defer { retainAndClose(rendered) }
        let baselineDelta = try wheelScrollDelta(in: rendered.scrollView)
        try XCTSkipIf(
            abs(baselineDelta) <= 1,
            "Known-good NSScrollView does not respond to synthesized CGEvent wheel input here."
        )

        setScrollOffset(240, in: rendered.scrollView)
        rendered.controller.play()
        settle(rendered.host)
        let playingDelta = try wheelScrollDelta(in: rendered.scrollView)
        XCTAssertGreaterThan(abs(playingDelta), 1)
        rendered.controller.pause()
    }

    @MainActor
    func testKeyboardScrollStillWorksWhilePlaybackNarrationIsSuspended() throws {
        let rendered = try narratedPlayingScrollHarness()
        defer { retainAndClose(rendered) }
        let baselineDelta = try keyboardScrollDelta(in: rendered.scrollView)
        try XCTSkipIf(
            abs(baselineDelta) <= 1,
            "Known-good NSScrollView does not respond to synthesized CGEvent key input here."
        )

        setScrollOffset(240, in: rendered.scrollView)
        rendered.controller.play()
        settle(rendered.host)
        let playingDelta = try keyboardScrollDelta(in: rendered.scrollView)
        XCTAssertGreaterThan(abs(playingDelta), 1)
        rendered.controller.pause()
    }

    @MainActor
    func testEditorSpaceInputDoesNotToggleActivePlayerPlayback() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(presentation: presentation)
        controller.start()
        XCTAssertFalse(controller.isPlaying)

        let host = NSHostingView(
            rootView: PlayerAndEditorHarness(controller: controller)
                .frame(width: 680, height: 620)
        )
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 620)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        defer {
            controller.pause()
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }
        settle(host)

        let editor = try XCTUnwrap(
            allScrollViews(in: host)
                .compactMap { $0.documentView as? NSTextView }
                .first { $0.font == CodeTextView.baseFont }
        )
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        XCTAssertTrue(window.makeFirstResponder(editor))
        let before = editor.string
        let cgEvent = try XCTUnwrap(
            CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)
        )
        cgEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: [32])
        let spaceEvent = try XCTUnwrap(NSEvent(cgEvent: cgEvent))
        let playerHandledSpaceAsKeyEquivalent = window.performKeyEquivalent(with: spaceEvent)
        settle(host)
        XCTAssertFalse(
            playerHandledSpaceAsKeyEquivalent,
            "The player must not register Space as a window-wide key equivalent."
        )
        XCTAssertFalse(controller.isPlaying)

        window.sendEvent(spaceEvent)
        settle(host)

        try XCTSkipIf(
            editor.string == before && controller.isPlaying == false,
            "The hosted XCTest process did not deliver the known-good Space event to either responder or shortcut handling."
        )
        XCTAssertEqual(editor.string, before + " ")
        XCTAssertFalse(
            controller.isPlaying,
            "Typing Space in the code editor must not trigger window-wide player playback."
        )
    }

    @MainActor
    func testPlayerDeactivatesWhenRemovedFromWindow() {
        let controller = Self.makeController(
            presentation: SwiftPilotPresentationContent.lesson3
        )
        controller.start()
        controller.play()
        XCTAssertTrue(controller.isPlaying)

        let hostingView = NSHostingView(
            rootView: LessonPresentationPlayer(
                controller: controller,
                initiallyExpanded: true,
                onReadDeeper: {}
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = hostingView
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        window.contentView = NSView()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        defer {
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }

        XCTAssertFalse(
            controller.isPlaying,
            "Removing the player must deactivate suspended narration and playback."
        )
    }

    @MainActor
    func testWorkspaceSessionKeepsPlayingControllerAliveAcrossLazyPlayerEviction() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let session = LessonWorkspaceSession(waitForAdvance: {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
        })
        session.activate(
            for: .swift(3),
            presentation: presentation,
            savedState: nil,
            persist: { _, _ in }
        )
        let controller = try XCTUnwrap(session.controller)
        controller.start()
        controller.play()

        let host = NSHostingView(
            rootView: WorkspaceLazyDocumentHarness(session: session)
                .frame(width: 680, height: 520)
        )
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 520)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = host
        window.orderFrontRegardless()
        defer {
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }
        settle(host)

        let scrollView = try XCTUnwrap(allScrollViews(in: host).first)
        let maximumOffset = max(
            0,
            (scrollView.documentView?.bounds.height ?? 0) - scrollView.contentView.bounds.height
        )
        XCTAssertGreaterThan(maximumOffset, 1_000)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: maximumOffset))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        settle(host)

        let playerIsEvictedOrOffscreen: Bool
        if let player = markers(named: "presentation-player-frame", in: host).first,
           let documentView = scrollView.documentView {
            let playerFrame = player.convert(player.bounds, to: documentView)
            playerIsEvictedOrOffscreen = !playerFrame.intersects(scrollView.documentVisibleRect)
        } else {
            playerIsEvictedOrOffscreen = true
        }
        XCTAssertTrue(playerIsEvictedOrOffscreen)
        XCTAssertTrue(
            controller.isPlaying,
            "Lazy offscreen eviction must not let the child deactivate the workspace-owned controller."
        )
        session.activate(
            for: .swift(2),
            presentation: SwiftPilotPresentationContent.lesson2,
            savedState: nil,
            persist: { _, _ in }
        )
        XCTAssertFalse(controller.isPlaying, "Changing lessons must still deactivate the old controller.")
        let replacementController = try XCTUnwrap(session.controller)
        replacementController.start()
        replacementController.play()
        session.cancel()
        XCTAssertFalse(
            replacementController.isPlaying,
            "Leaving the workspace must still let the owning session deactivate playback."
        )
    }

    @MainActor
    func testWorkspaceExpansionActionsSurvivePlayerRemountWithSameController() throws {
        let presentation = SwiftPilotPresentationContent.lesson3
        let started = presentationState(
            status: .started,
            sceneID: presentation.scenes[1].id,
            presentation: presentation
        )
        let completed = presentationState(
            status: .completed,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let scenarios: [(name: String, state: LessonPresentationState?, action: String)] = [
            ("Start", nil, "presentation-action-start"),
            ("Resume", started, "presentation-action-resume"),
            ("Replay", completed, "presentation-action-replay")
        ]

        for scenario in scenarios {
            let session = LessonWorkspaceSession(waitForAdvance: {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            })
            session.activate(
                for: .swift(3),
                presentation: presentation,
                savedState: scenario.state,
                persist: { _, _ in }
            )
            let controller = try XCTUnwrap(session.controller)
            let host = NSHostingView(
                rootView: WorkspacePlayerRemountHarness(
                    session: session,
                    mountGeneration: 0
                )
                .frame(width: 680, height: 420)
            )
            host.frame = NSRect(x: 0, y: 0, width: 680, height: 420)
            let window = NSWindow(
                contentRect: host.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.animationBehavior = .none
            window.contentView = host
            window.orderFrontRegardless()
            defer {
                window.orderOut(nil)
                Self.retainedHostedWindows.append(window)
            }
            settle(host)

            try invokeAction(scenario.action, in: host)
            settle(host)
            XCTAssertEqual(
                markers(named: "presentation-active-scene", in: host).count,
                1,
                "\(scenario.name) must expand the active scene before remount."
            )
            if !controller.isPlaying {
                try invokeAction("presentation-action-play-pause", in: host)
                settle(host)
            }
            XCTAssertTrue(controller.isPlaying)

            host.rootView = WorkspacePlayerRemountHarness(
                session: session,
                mountGeneration: 1
            )
            .frame(width: 680, height: 420)
            settle(host)

            XCTAssertTrue(controller === session.controller)
            XCTAssertTrue(controller.isPlaying, "\(scenario.name) playback must survive remount.")
            XCTAssertEqual(
                markers(named: "presentation-active-scene", in: host).count,
                1,
                "\(scenario.name) must remount the active scene, not Ready to resume."
            )
            XCTAssertTrue(markers(named: "presentation-action-resume", in: host).isEmpty)
            session.cancel()
        }
    }

    @MainActor
    func testRenderedAccessibilityContract() throws {
        let baselineHost = NSHostingView(
            rootView: Button("Accessibility baseline") {}
                .accessibilityLabel("Accessibility baseline control")
                .frame(width: 240, height: 80)
        )
        let baselineWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        baselineWindow.animationBehavior = .none
        baselineWindow.contentView = baselineHost
        baselineWindow.orderFrontRegardless()
        baselineHost.frame = baselineWindow.contentView?.bounds ?? .zero
        baselineHost.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        let baselineValues = accessibilityStrings(in: baselineHost)
        defer {
            baselineWindow.orderOut(nil)
            Self.retainedHostedWindows.append(baselineWindow)
        }
        try XCTSkipIf(
            baselineValues.isEmpty,
            "The known-good SwiftUI Button exposes no NSAccessibility output in this XCTest process, so hosted SwiftUI accessibility is unsupported here."
        )

        let presentation = SwiftPilotPresentationContent.lesson3
        let controller = Self.makeController(
            presentation: presentation,
            reduceMotion: true
        )
        controller.start()
        controller.play()
        defer { controller.pause() }
        XCTAssertEqual(controller.visualPhase, .after)

        var environmentValues = EnvironmentValues()
        environmentValues._accessibilityReduceMotion = true
        XCTAssertTrue(environmentValues.accessibilityReduceMotion)

        let hostingView = NSHostingView(
            rootView: LessonPresentationPlayer(
                controller: controller,
                initiallyExpanded: true
            )
            // `accessibilityReduceMotion` is get-only in EnvironmentValues;
            // this is its public writable test override in SwiftUICore.
            .environment(\._accessibilityReduceMotion, true)
        )
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        defer {
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        let renderedValues = accessibilityStrings(in: hostingView)
        XCTAssertFalse(
            renderedValues.isEmpty,
            "The baseline SwiftUI control exposed NSAccessibility output, but the player exposed none."
        )
        let rendered = renderedValues.joined(separator: " | ")

        for required in [
            "Scene 1 of 4",
            "Playback state",
            "Playing",
            "Focused code token",
            "var",
            "Result",
            presentation.scenes[0].caption,
            presentation.scenes[0].staticDescription,
            "Back one scene",
            "Next scene",
            "Pause presentation",
            "Replay presentation",
            "Skip presentation",
            "Turn narration on",
            "Show transcript",
            "Read deeper"
        ] {
            XCTAssertTrue(
                rendered.localizedCaseInsensitiveContains(required),
                "Missing rendered accessibility content: \(required)\n\(rendered)"
            )
        }
        XCTAssertTrue(
            rendered.contains(
                "The source declares a mutable binding named count with the Int literal 1."
            ),
            "Reduce Motion must render the authored after-state directly."
        )
        XCTAssertFalse(
            rendered.contains("An empty mutation lane waits for a variable declaration."),
            "Reduce Motion must not expose an intermediate before/travel state."
        )
    }

    @MainActor
    private static func makeController(
        presentation: LessonPresentation,
        savedState: LessonPresentationState? = nil,
        reduceMotion: Bool = false,
        narrator: PresentationNarrating? = nil
    ) -> PresentationPlayerController {
        PresentationPlayerController(
            lessonKey: .swift(3),
            presentation: presentation,
            savedState: savedState,
            persist: { _, _ in },
            waitForAdvance: {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            },
            narrator: narrator ?? UnavailableNarrator(),
            reduceMotion: { reduceMotion }
        )
    }

    private func accessibilityStrings(in element: Any) -> [String] {
        guard let accessible = element as? NSAccessibilityProtocol else { return [] }
        var values: [String] = []
        if let label = accessible.accessibilityLabel() { values.append(label) }
        if let value = accessible.accessibilityValue() as? String { values.append(value) }
        if let help = accessible.accessibilityHelp() { values.append(help) }
        let children = accessible.accessibilityChildren()
            ?? accessible.accessibilityChildrenInNavigationOrder()
            ?? []
        for child in NSAccessibility.unignoredChildren(from: children) {
            values.append(contentsOf: accessibilityStrings(in: child))
        }
        return values
    }

    private func markers(named identifier: String, in view: NSView) -> [NSView] {
        var matches: [NSView] = []
        if view.identifier?.rawValue == identifier {
            matches.append(view)
        }
        for child in view.subviews {
            matches.append(contentsOf: markers(named: identifier, in: child))
        }
        return matches
    }

    @MainActor
    private func playerStateRenderings(
        presentation: LessonPresentation,
        width: CGFloat
    ) throws -> [HostedPlayer] {
        let started = presentationState(
            status: .started,
            sceneID: presentation.scenes[1].id,
            presentation: presentation
        )
        let skipped = presentationState(
            status: .skipped,
            sceneID: nil,
            presentation: presentation
        )
        let completed = presentationState(
            status: .completed,
            sceneID: presentation.scenes.last?.id,
            presentation: presentation
        )
        let active = Self.makeController(presentation: presentation, savedState: started)
        let transcript = Self.makeController(presentation: presentation, savedState: started)
        transcript.toggleTranscript()
        let narration = Self.makeController(
            presentation: presentation,
            savedState: started,
            narrator: AvailableNarrator()
        )
        narration.toggleNarration()

        return [
            try renderPlayer(name: "poster", controller: Self.makeController(presentation: presentation), width: width),
            try renderPlayer(name: "resume", controller: Self.makeController(presentation: presentation, savedState: started), width: width),
            try renderPlayer(name: "active", controller: active, width: width, initiallyExpanded: true),
            try renderPlayer(name: "skipped", controller: Self.makeController(presentation: presentation, savedState: skipped), width: width),
            try renderPlayer(name: "completed", controller: Self.makeController(presentation: presentation, savedState: completed), width: width),
            try renderPlayer(name: "unavailable", controller: Self.makeController(presentation: unavailablePresentation(from: presentation)), width: width),
            try renderPlayer(name: "transcript", controller: transcript, width: width, initiallyExpanded: true),
            try renderPlayer(name: "narration-off", controller: narration, width: width, initiallyExpanded: true)
        ]
    }

    @MainActor
    private func renderPlayer(
        name: String,
        controller: PresentationPlayerController,
        width: CGFloat,
        initiallyExpanded: Bool = false,
        showsReadDeeper: Bool = true,
        onReadDeeper: @escaping () -> Void = {}
    ) throws -> HostedPlayer {
        let host = NSHostingView(
            rootView: AnyView(
                LessonPresentationPlayer(
                    controller: controller,
                    initiallyExpanded: initiallyExpanded,
                    showsReadDeeper: showsReadDeeper,
                    onReadDeeper: onReadDeeper
                )
                .frame(width: width)
            )
        )
        let size = host.fittingSize
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = host
        window.orderFrontRegardless()
        settle(host)
        return HostedPlayer(name: name, host: host, window: window)
    }

    @MainActor
    private func renderScrollHarness(
        controller: PresentationPlayerController,
        initiallyExpanded: Bool
    ) throws -> HostedScrollPlayer {
        let host = NSHostingView(
            rootView: AnyView(
                PlayerOuterScrollHarness(
                    controller: controller,
                    initiallyExpanded: initiallyExpanded
                )
                .frame(width: 720, height: 500)
            )
        )
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 500)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settle(host)
        let scrollView = try XCTUnwrap(
            allScrollViews(in: host).max {
                ($0.documentView?.frame.height ?? 0) < ($1.documentView?.frame.height ?? 0)
            }
        )
        return HostedScrollPlayer(
            host: host,
            window: window,
            scrollView: scrollView,
            controller: controller
        )
    }

    @MainActor
    private func narratedPlayingScrollHarness() throws -> HostedScrollPlayer {
        let presentation = SwiftPilotPresentationContent.lesson3
        return try renderScrollHarness(
            controller: Self.makeController(
                presentation: presentation,
                savedState: presentationState(
                    status: .started,
                    sceneID: presentation.scenes[1].id,
                    presentation: presentation
                ),
                narrator: SuspendedNarrator()
            ),
            initiallyExpanded: true
        )
    }

    @MainActor
    private func settle(_ host: NSView) {
        for _ in 0..<4 {
            host.layoutSubtreeIfNeeded()
            _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.002))
        }
        host.layoutSubtreeIfNeeded()
    }

    @MainActor
    private func retainAndClose(_ rendering: HostedPlayer) {
        rendering.window.orderOut(nil)
        Self.retainedHostedWindows.append(rendering.window)
    }

    @MainActor
    private func retainAndClose(_ rendering: HostedScrollPlayer) {
        rendering.window.orderOut(nil)
        Self.retainedHostedWindows.append(rendering.window)
    }

    private func presentationState(
        status: PresentationStatus,
        sceneID: String?,
        presentation: LessonPresentation
    ) -> LessonPresentationState {
        LessonPresentationState(
            status: status,
            lastSceneID: sceneID,
            presentationRevision: presentation.provenance.revision,
            firstStartedAt: Date(timeIntervalSinceReferenceDate: 1),
            lastOpenedAt: Date(timeIntervalSinceReferenceDate: 2),
            replayCount: 0,
            presentationID: presentation.id
        )
    }

    private func unavailablePresentation(from presentation: LessonPresentation) -> LessonPresentation {
        LessonPresentation(
            id: "\(presentation.id)-unavailable",
            title: presentation.title,
            posterDescription: presentation.posterDescription,
            posterState: presentation.posterState,
            scenes: [],
            transcript: presentation.transcript,
            narrationLocale: presentation.narrationLocale,
            finalRecallQuestionID: presentation.finalRecallQuestionID,
            aiCodeExercise: presentation.aiCodeExercise,
            conceptIDs: presentation.conceptIDs,
            objectiveMappings: presentation.objectiveMappings,
            provenance: presentation.provenance
        )
    }

    private func playerFrame(in host: NSView) throws -> NSRect {
        let marker = try XCTUnwrap(markers(named: "presentation-player-frame", in: host).first)
        return marker.convert(marker.bounds, to: host)
    }

    @MainActor
    private func invokeAction(_ identifier: String, in host: NSView) throws {
        let marker = try XCTUnwrap(
            markers(named: identifier, in: host).first as? RuntimeNavigationActionView,
            "Missing production action marker \(identifier)"
        )
        marker.invoke()
    }

    private func allScrollViews(in view: NSView) -> [NSScrollView] {
        var result = view is NSScrollView ? [view as! NSScrollView] : []
        for child in view.subviews {
            result.append(contentsOf: allScrollViews(in: child))
        }
        return result
    }

    private func actionMarkers(in view: NSView) -> [RuntimeNavigationActionView] {
        var result = view is RuntimeNavigationActionView
            ? [view as! RuntimeNavigationActionView]
            : []
        for child in view.subviews {
            result.append(contentsOf: actionMarkers(in: child))
        }
        return result
    }

    @MainActor
    private func hostedSwiftUIFocusIsSupported() -> Bool {
        let host = NSHostingView(
            rootView: HostedFocusBaselineHarness()
                .frame(width: 240, height: 80)
        )
        host.frame = NSRect(x: 0, y: 0, width: 240, height: 80)
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        window.contentView = host
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settle(host)
        defer {
            window.orderOut(nil)
            Self.retainedHostedWindows.append(window)
        }

        guard let responder = window.firstResponder as? NSView,
              let marker = markers(
                named: "hosted-focus-baseline-control",
                in: host
              ).first else {
            return false
        }
        let responderRect = responder.convert(responder.bounds, to: host)
        let markerRect = marker.convert(marker.bounds, to: host)
        return markerRect.insetBy(dx: -1, dy: -1).contains(responderRect)
    }

    private func expectedEntryMode(
        _ status: PresentationStatus,
        presentation: LessonPresentation
    ) -> PresentationEntryMode {
        switch status {
        case .notStarted:
            return .expandedPoster
        case .started:
            return .compactResume(sceneID: presentation.scenes[0].id)
        case .skipped, .completed:
            return .compactSummary(status: status)
        }
    }

    private func setScrollOffset(_ y: CGFloat, in scrollView: NSScrollView) {
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func assertResponder(
        _ responder: NSView,
        isInsidePlayerIn host: NSView,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let marker = markers(named: "presentation-player-frame", in: host).first else {
            XCTFail("Missing player marker", file: file, line: line)
            return
        }
        let playerRect = marker.convert(marker.bounds, to: host)
        let responderRect = responder.convert(responder.bounds, to: host)
        XCTAssertTrue(
            playerRect.insetBy(dx: -1, dy: -1).contains(responderRect),
            "First responder \(responderRect) is outside leaf player \(playerRect)",
            file: file,
            line: line
        )
    }

    private func wheelScrollDelta(in scrollView: NSScrollView) throws -> CGFloat {
        let before = scrollView.contentView.bounds.origin.y
        let cgEvent = try XCTUnwrap(
            CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: -90,
                wheel2: 0,
                wheel3: 0
            )
        )
        scrollView.scrollWheel(with: try XCTUnwrap(NSEvent(cgEvent: cgEvent)))
        scrollView.layoutSubtreeIfNeeded()
        return scrollView.contentView.bounds.origin.y - before
    }

    private func keyboardScrollDelta(in scrollView: NSScrollView) throws -> CGFloat {
        let before = scrollView.contentView.bounds.origin.y
        let cgEvent = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 125, keyDown: true))
        scrollView.keyDown(with: try XCTUnwrap(NSEvent(cgEvent: cgEvent)))
        scrollView.layoutSubtreeIfNeeded()
        return scrollView.contentView.bounds.origin.y - before
    }
}

private struct HostedPlayer {
    let name: String
    let host: NSHostingView<AnyView>
    let window: NSWindow
}

private struct HostedScrollPlayer {
    let host: NSHostingView<AnyView>
    let window: NSWindow
    let scrollView: NSScrollView
    let controller: PresentationPlayerController
}

@MainActor
private struct PlayerActionScenario {
    let name: String
    let marker: String
    let makePlayer: () -> (PresentationPlayerController, Bool)
}

private struct PlayerOuterScrollHarness: View {
    @ObservedObject var controller: PresentationPlayerController
    let initiallyExpanded: Bool

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 24) {
                Color.clear.frame(height: 420)
                LessonPresentationPlayer(
                    controller: controller,
                    initiallyExpanded: initiallyExpanded
                )
                Color.clear.frame(height: 900)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct PlayerAndEditorHarness: View {
    @ObservedObject var controller: PresentationPlayerController
    @State private var code = "let value = 1"

    var body: some View {
        VStack(spacing: 16) {
            LessonPresentationPlayer(
                controller: controller,
                initiallyExpanded: true,
                deactivatesOnDisappear: false
            )
            CodeTextView(text: $code)
                .frame(height: 180)
        }
        .padding()
    }
}

private struct HostedFocusBaselineHarness: View {
    @FocusState private var isFocused: Bool

    var body: some View {
        Button("Focus baseline") {}
            .focused($isFocused)
            .background {
                RuntimeViewMarker(identifier: "hosted-focus-baseline-control")
            }
            .onAppear {
                DispatchQueue.main.async { isFocused = true }
            }
    }
}

private struct WorkspacePlayerExpansionHarness: View {
    @ObservedObject var session: LessonWorkspaceSession

    var body: some View {
        if let controller = session.controller {
            LessonPresentationPlayer(
                controller: controller,
                expansionRequestGeneration: session.playerExpansionGeneration
            )
        }
    }
}

private struct WorkspaceLazyDocumentHarness: View {
    @ObservedObject var session: LessonWorkspaceSession

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                if let controller = session.controller {
                    LessonPresentationPlayer(
                        controller: controller,
                        initiallyExpanded: true,
                        deactivatesOnDisappear: false
                    )
                    .frame(height: 360)
                }
                Color.clear.frame(height: 1_200)
                Color.clear
                    .frame(height: 500)
                    .background { RuntimeViewMarker(identifier: "lazy-practice") }
            }
        }
    }
}

private struct WorkspacePlayerRemountHarness: View {
    @ObservedObject var session: LessonWorkspaceSession
    let mountGeneration: Int

    var body: some View {
        Group {
            if let controller = session.controller {
                LessonPresentationPlayer(
                    controller: controller,
                    initiallyExpanded: session.playerExpansionLessonKey == controller.lessonKey,
                    deactivatesOnDisappear: false,
                    onExpanded: {
                        session.recordPlayerExpanded(for: controller.lessonKey)
                    }
                )
                .id(mountGeneration)
            }
        }
    }
}

private struct WorkspaceReduceMotionHarness: View {
    let session: LessonWorkspaceSession
    let reduceMotion: Bool

    var body: some View {
        Color.clear
            .modifier(LessonWorkspaceReduceMotionModifier(session: session))
            .environment(\._accessibilityReduceMotion, reduceMotion)
    }
}

@MainActor
private final class UnavailableNarrator: PresentationNarrating {
    func isAvailable(for locale: String) -> Bool { false }
    func speak(_ text: String, locale: String) async {}
    func stop() {}
}

@MainActor
private final class AvailableNarrator: PresentationNarrating {
    func isAvailable(for locale: String) -> Bool { true }
    func speak(_ text: String, locale: String) async {}
    func stop() {}
}

@MainActor
private final class SuspendedNarrator: PresentationNarrating {
    private var continuation: CheckedContinuation<Void, Never>?

    func isAvailable(for locale: String) -> Bool { true }

    func speak(_ text: String, locale: String) async {
        await withCheckedContinuation { continuation = $0 }
    }

    func stop() {
        continuation?.resume()
        continuation = nil
    }
}
