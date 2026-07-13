import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class CourseWorkspaceLayoutTests: XCTestCase {
    private static var retainedHostedWindows: [NSWindow] = []

    func testAuthoredLessonHasOnePlaybackSurfaceAndEditablePracticeEditor() throws {
        let fixture = try CourseWorkspaceFixture()
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        let authoredLesson = try XCTUnwrap(
            model.lessons.first { $0.presentation != nil },
            "The fixture must include an authored lesson presentation."
        )
        model.selectLesson(authoredLesson.id)

        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(
            markers(named: "legacy-walkthrough-action", in: rendered.host).count,
            0,
            "The presentation player must be the authored lesson's only playback surface."
        )
        XCTAssertEqual(
            markers(named: "presentation-playback-surface", in: rendered.host).count,
            1,
            "An authored lesson must mount exactly one production presentation player."
        )
        XCTAssertEqual(markers(named: "presentation-player-frame", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-document-header", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-path", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-recall-not-answered", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-not-passed", in: rendered.host).count, 1)
        try scrollToPractice(in: rendered.host)
        XCTAssertEqual(markers(named: "practice-workspace", in: rendered.host).count, 1)
        XCTAssertTrue(try codeEditorTextView(in: rendered.host).isEditable)
    }

    func testPersistedRecallAnswerSurvivesLazyRemountAndLessonRoundTrip() throws {
        for wasCorrect in [false, true] {
            let fixture = try CourseWorkspaceFixture()
            let model = fixture.makeModel()
            model.openCourse(.swiftDevelopment)
            let lesson = try XCTUnwrap(model.lessons.first { $0.presentation != nil })
            let question = try XCTUnwrap(lesson.deepContent?.recallQuestions.first {
                $0.id == lesson.presentation?.finalRecallQuestionID
            })
            let lessonKey = LessonKey.swift(lesson.id)
            model.selectLesson(lesson.id)

            let rendered = hostInWindow(
                CourseWorkspaceView(model: model, canPresentLearningStages: true),
                size: NSSize(width: 680, height: 520)
            )
            defer { retainWindow(rendered.window) }

            fixture.recordRecallAnswer(
                lessonKey: lessonKey,
                questionID: question.id,
                wasCorrect: wasCorrect
            )
            refresh(rendered.host)

            func assertPersistedTruth(_ context: String) throws {
                XCTAssertEqual(
                    markers(named: "lesson-stage-recall-answered", in: rendered.host).count,
                    1,
                    context
                )
                XCTAssertEqual(markers(named: "lesson-recall-answered", in: rendered.host).count, 1, context)
                XCTAssertEqual(
                    markers(
                        named: wasCorrect ? "lesson-recall-correct" : "lesson-recall-incorrect",
                        in: rendered.host
                    ).count,
                    1,
                    context
                )
                XCTAssertEqual(markers(named: "lesson-recall-explanation", in: rendered.host).count, 1, context)
                XCTAssertEqual(markers(named: "lesson-recall-continue", in: rendered.host).count, 1, context)
                XCTAssertEqual(
                    markers(named: "lesson-recall-choice-locked", in: rendered.host).count,
                    question.choices.count,
                    context
                )
                XCTAssertTrue(
                    markers(named: "lesson-recall-choice-selected", in: rendered.host).isEmpty,
                    "Persisted answer truth must not fabricate a selected choice. \(context)"
                )
            }

            try assertPersistedTruth("initial")
            try scrollToPractice(in: rendered.host)
            let outerScroll = try scrollView(named: "lesson-document-scroll", in: rendered.host)
            outerScroll.contentView.scroll(to: .zero)
            outerScroll.reflectScrolledClipView(outerScroll.contentView)
            refresh(rendered.host)
            try assertPersistedTruth("lazy remount")

            let replacement = try XCTUnwrap(model.lessons.first { $0.id != lesson.id })
            model.selectLesson(replacement.id)
            refresh(rendered.host)
            model.selectLesson(lesson.id)
            refresh(rendered.host)
            try assertPersistedTruth("lesson round trip")

            fixture.recordRecallAnswer(
                lessonKey: lessonKey,
                questionID: question.id,
                wasCorrect: !wasCorrect
            )
            XCTAssertEqual(fixture.recallAnswerCount(lessonKey: lessonKey, questionID: question.id), 1)
            XCTAssertEqual(fixture.recallAnswer(lessonKey: lessonKey, questionID: question.id), wasCorrect)
        }
    }

    func testPlayerFirstLessonDocumentAndPracticeWorkspaceStayBoundedAndScrollable() throws {
        let fixture = try CourseWorkspaceFixture()
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        let authoredLesson = try XCTUnwrap(model.lessons.first { $0.presentation != nil })
        model.selectLesson(authoredLesson.id)

        for size in [NSSize(width: 680, height: 520), NSSize(width: 1280, height: 860)] {
            let rendered = hostInWindow(
                CourseWorkspaceView(model: model, canPresentLearningStages: true),
                size: size
            )
            defer { retainWindow(rendered.window) }

            XCTAssertEqual(markers(named: "lesson-document-scroll", in: rendered.host).count, 1)
            XCTAssertTrue(markers(named: "learning-scroll", in: rendered.host).isEmpty)

            let outerScroll = try scrollView(named: "lesson-document-scroll", in: rendered.host)
            let documentHeight = outerScroll.documentView?.bounds.height ?? 0
            let documentWidth = outerScroll.documentView?.bounds.width ?? 0
            XCTAssertGreaterThan(
                documentHeight,
                outerScroll.contentView.bounds.height + 100,
                "The lesson and finite practice workspace must form one vertically scrollable document."
            )
            XCTAssertLessThanOrEqual(
                documentWidth,
                outerScroll.contentView.bounds.width + 1,
                "The vertical lesson document must not create horizontal overflow."
            )
            assertFiniteAndInside(
                outerScroll.convert(outerScroll.bounds, to: rendered.host),
                rootBounds: rendered.host.bounds
            )

            let initialMarkers = [
                "presentation-player-frame",
                "lesson-document-header",
                "lesson-stage-path"
            ]
            var documentFrames = try initialMarkers.map {
                try documentFrame(named: $0, in: rendered.host, scrollView: outerScroll)
            }
            try scrollToPractice(in: rendered.host)
            documentFrames.append(
                try documentFrame(
                    named: "practice-workspace",
                    in: rendered.host,
                    scrollView: outerScroll
                )
            )
            for pair in zip(documentFrames, documentFrames.dropFirst()) {
                XCTAssertLessThan(
                    pair.0.midY,
                    pair.1.midY,
                    "Expected player, header, path, and practice in document order at \(Int(size.width))x\(Int(size.height))."
                )
            }

            let player = documentFrames[0]
            let header = documentFrames[1]
            XCTAssertEqual(player.minX, header.minX, accuracy: 1.5)
            XCTAssertEqual(player.maxX, header.maxX, accuracy: 1.5)
            XCTAssertGreaterThanOrEqual(player.minX, 15)

            let upperPane = try frame(named: "workspace-upper-pane", in: rendered.host)
            let outputPane = try frame(named: "run-output-pane", in: rendered.host)
            XCTAssertGreaterThanOrEqual(upperPane.height, 80)
            XCTAssertGreaterThanOrEqual(outputPane.height, 80)
            XCTAssertTrue(upperPane.width.isFinite && upperPane.height.isFinite)
            XCTAssertTrue(outputPane.width.isFinite && outputPane.height.isFinite)
            for identifier in ["workspace-upper-pane", "run-output-pane"] {
                let marker = try XCTUnwrap(markers(named: identifier, in: rendered.host).first)
                marker.scrollToVisible(marker.bounds)
                refresh(rendered.host)
                XCTAssertTrue(
                    isMeaningfullyVisible(marker, in: outerScroll),
                    "\(identifier) must be reachable within the outer lesson document."
                )
            }

            if size == NSSize(width: 680, height: 520) {
                XCTAssertTrue(markers(named: "wide-workspace-split", in: rendered.host).isEmpty)
                let picker = try frame(named: "narrow-panel-picker", in: rendered.host)
                let selectedPanel = try frame(named: "narrow-selected-panel", in: rendered.host)
                let currentUpperPane = try frame(named: "workspace-upper-pane", in: rendered.host)
                XCTAssertLessThanOrEqual(picker.height, 44)
                XCTAssertGreaterThanOrEqual(selectedPanel.height, 80)
                XCTAssertTrue(currentUpperPane.insetBy(dx: -1, dy: -1).contains(picker))
                XCTAssertTrue(currentUpperPane.insetBy(dx: -1, dy: -1).contains(selectedPanel))
            } else {
                XCTAssertEqual(markers(named: "wide-workspace-split", in: rendered.host).count, 1)
                XCTAssertTrue(markers(named: "narrow-panel-picker", in: rendered.host).isEmpty)
            }
        }
    }

    func testUnsupportedPresentationUsesStableUnavailablePlayerBeforeUsableContent() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "future-presentation-lessons",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let fixture = try CourseWorkspaceFixture(lessonData: Data(contentsOf: fixtureURL))
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        XCTAssertTrue(model.currentLesson.hasUnsupportedPresentation)
        fixture.seedPresentationState(
            LessonPresentationState(
                status: .started,
                lastSceneID: "legacy-scene",
                presentationRevision: 1,
                firstStartedAt: Date(timeIntervalSince1970: 1_700_000_000),
                lastOpenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                replayCount: 0,
                presentationID: "older-supported-presentation"
            ),
            for: model.selectedLessonKey ?? .swift(model.selectedLessonID)
        )

        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(markers(named: "presentation-player-frame", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "presentation-playback-surface", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-content-read-only", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-path", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-watch-unavailable", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-watch-disabled", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-recall-unavailable", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-unavailable", in: rendered.host).count, 1)
        XCTAssertTrue(markers(named: "lesson-stage-recall-enabled", in: rendered.host).isEmpty)
        XCTAssertTrue(markers(named: "lesson-stage-modify-enabled", in: rendered.host).isEmpty)
        let player = try frame(named: "presentation-player-frame", in: rendered.host)
        XCTAssertEqual(player.width / player.height, 16.0 / 9.0, accuracy: 0.03)
        let outerScroll = try scrollView(named: "lesson-document-scroll", in: rendered.host)
        let initialMarkers = [
            "presentation-player-frame",
            "lesson-document-header",
            "lesson-stage-path",
            "lesson-content-read-only"
        ]
        var documentFrames = try initialMarkers.map {
            try documentFrame(named: $0, in: rendered.host, scrollView: outerScroll)
        }
        try scrollToPractice(in: rendered.host)
        XCTAssertEqual(markers(named: "practice-workspace", in: rendered.host).count, 1)
        documentFrames.append(
            try documentFrame(named: "practice-workspace", in: rendered.host, scrollView: outerScroll)
        )
        for pair in zip(documentFrames, documentFrames.dropFirst()) {
            XCTAssertLessThan(
                pair.0.midY,
                pair.1.midY,
                "Unsupported authored lessons must keep player, header, path, warning, and practice in order."
            )
        }
        XCTAssertTrue(try codeEditorTextView(in: rendered.host).isEditable)
    }

    func testDecodedEmptyPresentationDisablesUnavailableWatchStage() throws {
        let authoredLesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        var lessonObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(authoredLesson))
                as? [String: Any]
        )
        var presentationObject = try XCTUnwrap(lessonObject["presentation"] as? [String: Any])
        presentationObject["scenes"] = []
        lessonObject["presentation"] = presentationObject
        let fixture = try CourseWorkspaceFixture(
            lessonData: JSONSerialization.data(withJSONObject: [lessonObject])
        )
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)

        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(markers(named: "presentation-player-frame", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-watch-unavailable", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-watch-disabled", in: rendered.host).count, 1)
    }

    func testPlayerOmitsReadDeeperWhenDeepContentIsNotUsable() throws {
        let authoredLesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        let encoded = try JSONEncoder().encode(authoredLesson)
        let baseObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        let deepContentVariants: [Any] = [
            NSNull(),
            ["schemaVersion": LessonDeepContent.currentSchemaVersion],
            ["schemaVersion": LessonDeepContent.currentSchemaVersion + 1]
        ]

        for (index, deepContent) in deepContentVariants.enumerated() {
            var lessonObject = baseObject
            lessonObject["deepContent"] = deepContent
            let fixture = try CourseWorkspaceFixture(
                lessonData: JSONSerialization.data(withJSONObject: [lessonObject])
            )
            let model = fixture.makeModel()
            model.openCourse(.swiftDevelopment)
            XCTAssertNotNil(model.currentLesson.presentation)
            XCTAssertNil(model.currentLesson.deepContent)

            let rendered = hostInWindow(
                CourseWorkspaceView(model: model, canPresentLearningStages: true),
                size: NSSize(width: 680, height: 520)
            )
            defer { retainWindow(rendered.window) }

            XCTAssertEqual(markers(named: "presentation-player-frame", in: rendered.host).count, 1)
            XCTAssertTrue(
                markers(named: "presentation-action-read-deeper", in: rendered.host).isEmpty,
                "Deep-content variant \(index) must not expose an inert Read Deeper action."
            )
        }

        let normalFixture = try CourseWorkspaceFixture(lessons: [authoredLesson])
        let normalModel = normalFixture.makeModel()
        normalModel.openCourse(.swiftDevelopment)
        let normal = hostInWindow(
            CourseWorkspaceView(model: normalModel, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(normal.window) }
        XCTAssertEqual(
            markers(named: "presentation-action-read-deeper", in: normal.host).count,
            1
        )
    }

    func testUnsupportedPresentationKeepsAuthoredRecallAndModifyAvailable() throws {
        let fixture = try CourseWorkspaceFixture(
            lessonData: unsupportedPresentationLessonDataWithDeepContent()
        )
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        XCTAssertTrue(model.currentLesson.hasUnsupportedPresentation)
        XCTAssertNotNil(model.currentLesson.deepContent)

        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(markers(named: "lesson-stage-path", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-watch-disabled", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-recall-enabled", in: rendered.host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-enabled", in: rendered.host).count, 1)
    }

    func testRecallRequestCannotScrollAReplacementLessonAfterYield() throws {
        let fixture = try CourseWorkspaceFixture()
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        model.selectLesson(1)
        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: true),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        let recallAction = try XCTUnwrap(
            markers(named: "lesson-stage-recall-enabled", in: rendered.host).first
                as? RuntimeNavigationActionView,
            "The production Recall stage must expose its real navigation command."
        )
        recallAction.invoke()
        model.selectLesson(.swift(2), origin: .direct)
        refresh(rendered.host)

        let lessonDocument = try scrollView(named: "lesson-document-scroll", in: rendered.host)
        let detailTop = try XCTUnwrap(markers(named: "detail-top", in: rendered.host).first)
        XCTAssertTrue(
            intersectsTopFourPoints(detailTop, in: lessonDocument),
            "Lesson B must remain at detail-top after Lesson A's yielded Recall request."
        )
    }

    func testUnauthoredLessonOmitsSyntheticPlayerAndKeepsDeepLessonActions() throws {
        var lesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        lesson.id = 1_000
        lesson.title = "Custom deep lesson"
        lesson.presentation = nil
        let fixture = try CourseWorkspaceFixture(lessons: [lesson])
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)

        for size in [NSSize(width: 680, height: 520), NSSize(width: 1280, height: 860)] {
            let rendered = hostInWindow(
                CourseWorkspaceView(model: model, canPresentLearningStages: true),
                size: size
            )
            defer { retainWindow(rendered.window) }

            XCTAssertTrue(markers(named: "presentation-player-frame", in: rendered.host).isEmpty)
            XCTAssertTrue(markers(named: "presentation-playback-surface", in: rendered.host).isEmpty)
            let outerScroll = try scrollView(named: "lesson-document-scroll", in: rendered.host)
            let detailTop = try documentFrame(named: "detail-top", in: rendered.host, scrollView: outerScroll)
            let header = try documentFrame(named: "lesson-document-header", in: rendered.host, scrollView: outerScroll)
            XCTAssertGreaterThanOrEqual(
                header.minY - detailTop.maxY,
                17,
                "An unauthored lesson header needs the canonical 18pt top spacing at \(Int(size.width))x\(Int(size.height))."
            )
            XCTAssertEqual(markers(named: "read-deeper-button", in: rendered.host).count, 1)
            XCTAssertEqual(markers(named: "modify-button", in: rendered.host).count, 1)
        }
    }

    func testRepeatedSelectionResizeAndManualScrollDoNotBottomStick() throws {
        let fixture = try CourseWorkspaceFixture()
        let lessonIDs = fixture.lessonIDs
        let sequence = [
            try XCTUnwrap(lessonIDs.first),
            lessonIDs[lessonIDs.count / 2],
            try XCTUnwrap(lessonIDs.last),
            try XCTUnwrap(lessonIDs.first)
        ]
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: false),
            size: NSSize(width: 1280, height: 860)
        )
        defer { retainWindow(rendered.window) }

        for size in [
            NSSize(width: 1280, height: 860),
            NSSize(width: 680, height: 520),
            NSSize(width: 900, height: 640)
        ] {
            resize(rendered, to: size)
            let sidebar = try scrollView(named: "lesson-sidebar-scroll", in: rendered.host)
            let lessonDocument = try scrollView(named: "lesson-document-scroll", in: rendered.host)
            model.selectLesson(.swift(sequence[1]), origin: .programmatic)
            refresh(rendered.host)

            for lessonID in sequence {
                let key = LessonKey.swift(lessonID)
                model.selectLesson(key, origin: .programmatic)
                refresh(rendered.host)

                let selectedRow = try XCTUnwrap(
                    markers(named: "lesson-row-\(key.id)", in: rendered.host).first,
                    "The selected row must remain mounted after scrolling to \(key.id) at \(Int(size.width))x\(Int(size.height))."
                )
                XCTAssertTrue(
                    isMeaningfullyVisible(selectedRow, in: sidebar),
                    "Selected row \(key.id) must intersect the sidebar viewport at \(Int(size.width))x\(Int(size.height)). \(visibilityDiagnostics(selectedRow, in: sidebar))"
                )

                let detailTop = try XCTUnwrap(
                    markers(named: "detail-top", in: rendered.host).first
                )
                XCTAssertTrue(
                    intersectsTopFourPoints(detailTop, in: lessonDocument),
                    "Selecting \(key.id) must return the lesson document to its top."
                )
            }

            let documentHeight = sidebar.documentView?.bounds.height ?? 0
            let maximumOffset = max(0, documentHeight - sidebar.contentView.bounds.height)
            XCTAssertGreaterThan(maximumOffset, 40, "Sidebar fixture must be manually scrollable.")
            let manualOffset = maximumOffset * 0.72
            sidebar.contentView.scroll(to: NSPoint(x: 0, y: manualOffset))
            sidebar.reflectScrolledClipView(sidebar.contentView)
            let manuallyScrolledOrigin = sidebar.contentView.bounds.origin
            refresh(rendered.host)
            XCTAssertEqual(
                sidebar.contentView.bounds.origin.y,
                manuallyScrolledOrigin.y,
                accuracy: 0.5,
                "Ordinary recomputation must not snap a manually scrolled sidebar back to selection."
            )

            sidebar.contentView.scroll(to: .zero)
            sidebar.reflectScrolledClipView(sidebar.contentView)
            model.selectLesson(.swift(sequence[2]), origin: .programmatic)
            model.selectLesson(.swift(sequence[0]), origin: .direct)
            refresh(rendered.host)
            XCTAssertEqual(
                sidebar.contentView.bounds.origin.y,
                0,
                accuracy: 0.5,
                "A direct selection must supersede a yielded programmatic visibility request."
            )
        }
    }

    func testDirectSelectionKeepsFarOffRowsVisibleWithoutRecenteringVisibleRows() throws {
        let fixture = try CourseWorkspaceFixture()
        let lessonIDs = fixture.lessonIDs
        let firstID = try XCTUnwrap(lessonIDs.first)
        let secondID = lessonIDs[1]
        let model = fixture.makeModel()
        model.openCourse(.swiftDevelopment)
        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: false),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        let sidebar = try scrollView(named: "lesson-sidebar-scroll", in: rendered.host)
        model.selectLesson(.swift(try XCTUnwrap(lessonIDs.last)), origin: .programmatic)
        refresh(rendered.host)
        let documentHeight = sidebar.documentView?.bounds.height ?? 0
        let maximumOffset = max(0, documentHeight - sidebar.contentView.bounds.height)
        XCTAssertGreaterThan(maximumOffset, 40, "Sidebar fixture must be manually scrollable.")

        sidebar.contentView.scroll(to: NSPoint(x: 0, y: maximumOffset * 0.74))
        sidebar.reflectScrolledClipView(sidebar.contentView)
        refresh(rendered.host)

        XCTAssertGreaterThan(
            sidebar.contentView.bounds.origin.y,
            maximumOffset * 0.6,
            "The regression setup must leave the sidebar manually scrolled near the bottom."
        )

        model.selectLesson(.swift(firstID), origin: .direct)
        refresh(rendered.host)
        let firstRow = try XCTUnwrap(waitForMarker(
            named: "lesson-row-\(LessonKey.swift(firstID).id)",
            in: rendered.host
        ))
        XCTAssertTrue(
            isMeaningfullyVisible(firstRow, in: sidebar),
            "A direct keyboard-style selection of far-off Lesson 1 must minimally reveal it. \(visibilityDiagnostics(firstRow, in: sidebar))"
        )

        let originAfterFirstSelection = sidebar.contentView.bounds.origin
        model.selectLesson(.swift(secondID), origin: .direct)
        refresh(rendered.host)
        let secondRow = try XCTUnwrap(waitForMarker(
            named: "lesson-row-\(LessonKey.swift(secondID).id)",
            in: rendered.host
        ))
        XCTAssertTrue(
            isMeaningfullyVisible(secondRow, in: sidebar),
            "The next direct keyboard-style selection must keep Lesson 2 visible. \(visibilityDiagnostics(secondRow, in: sidebar))"
        )
        XCTAssertEqual(
            sidebar.contentView.bounds.origin.y,
            originAfterFirstSelection.y,
            accuracy: 0.5,
            "Selecting a row that is already meaningfully visible must not recenter the sidebar."
        )
    }

    func testRunOutputControlsAndResultsStayInsideOutputPane() async throws {
        let fixture = try CourseWorkspaceFixture()
        let model = fixture.makeModel(runCode: { _ in
            RunResult(
                stdout: "Hello",
                stderr: "",
                exitCode: 0,
                launchError: nil,
                workspaceWasSaved: true
            )
        })
        model.openCourse(.swiftDevelopment)
        let rendered = hostInWindow(
            CourseWorkspaceView(model: model, canPresentLearningStages: false),
            size: NSSize(width: 680, height: 520)
        )
        defer { retainWindow(rendered.window) }

        try scrollToPractice(in: rendered.host)
        let outputPane = try frame(named: "run-output-pane", in: rendered.host)
        for identifier in ["run-prediction-field", "run-button", "run-placeholder"] {
            let descendant = try frame(named: identifier, in: rendered.host)
            XCTAssertTrue(
                outputPane.insetBy(dx: -1, dy: -1).contains(descendant),
                "\(identifier) \(descendant) escapes output pane \(outputPane)."
            )
            XCTAssertGreaterThan(descendant.width, 0)
            XCTAssertGreaterThan(descendant.height, 0)
        }

        model.code = "print(\"Hello\")"
        model.run()
        for _ in 0..<20 where model.runResult == nil {
            await Task.yield()
            refresh(rendered.host)
        }
        try scrollToPractice(in: rendered.host)
        let refreshedOutputPane = try frame(named: "run-output-pane", in: rendered.host)
        let resultViewport = try frame(named: "run-result-scroll", in: rendered.host)
        XCTAssertTrue(
            refreshedOutputPane.insetBy(dx: -1, dy: -1).contains(resultViewport),
            "Result viewport \(resultViewport) escapes output pane \(refreshedOutputPane)."
        )
        XCTAssertGreaterThan(resultViewport.width, 0)
        XCTAssertGreaterThan(resultViewport.height, 0)
        XCTAssertTrue(markers(named: "run-placeholder", in: rendered.host).isEmpty)
    }

    func testSelectedRowVisibilityRejectsATwoPointSliver() {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 200))
        let row = NSView(frame: NSRect(x: 0, y: 98, width: 100, height: 33))
        document.addSubview(row)
        scrollView.documentView = document
        scrollView.contentView.scroll(to: .zero)

        XCTAssertEqual(row.frame.intersection(scrollView.documentVisibleRect).height, 2)
        XCTAssertFalse(
            isMeaningfullyVisible(row, in: scrollView),
            "A clipped row sliver must never satisfy selected-row visibility."
        )
    }

    private func hostInWindow<Content: View>(
        _ content: Content,
        size: NSSize
    ) -> (host: NSHostingView<Content>, window: NSWindow) {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        let container = NSView(frame: NSRect(origin: .zero, size: size))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        window.contentView = container
        window.setContentSize(size)
        window.orderFrontRegardless()
        host.frame = container.bounds
        refresh(host)
        return (host, window)
    }

    private func unsupportedPresentationLessonDataWithDeepContent() throws -> Data {
        let futureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "future-presentation-lessons",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        let futureLessons = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: futureURL)) as? [[String: Any]]
        )
        let futurePresentation = try XCTUnwrap(futureLessons.first?["presentation"])
        let authoredLesson = try XCTUnwrap(Curriculum.defaultLesson(id: 1))
        var authoredObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(authoredLesson))
                as? [String: Any]
        )
        authoredObject["presentation"] = futurePresentation
        return try JSONSerialization.data(withJSONObject: [authoredObject])
    }

    private func retainWindow(_ window: NSWindow) {
        window.animationBehavior = .none
        window.orderOut(nil)
        Self.retainedHostedWindows.append(window)
    }

    private func resize<Content: View>(
        _ rendered: (host: NSHostingView<Content>, window: NSWindow),
        to size: NSSize
    ) {
        rendered.window.setContentSize(size)
        rendered.host.frame = rendered.window.contentView?.bounds
            ?? NSRect(origin: .zero, size: size)
        refresh(rendered.host)
    }

    private func refresh(_ view: NSView) {
        for _ in 0..<3 {
            view.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
        }
        view.layoutSubtreeIfNeeded()
    }

    private func waitForMarker(
        named identifier: String,
        in view: NSView,
        timeout: TimeInterval = 5
    ) -> NSView? {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            refresh(view)
            if let marker = markers(named: identifier, in: view).first {
                return marker
            }
        } while Date() < deadline
        return nil
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

    private func codeEditorTextView(in view: NSView) throws -> NSTextView {
        let editors = descendantScrollViews(in: view).compactMap { scrollView -> NSTextView? in
            guard let textView = scrollView.documentView as? NSTextView,
                  textView.font == CodeTextView.baseFont
            else { return nil }
            return textView
        }
        XCTAssertEqual(editors.count, 1, "Expected one underlying practice editor NSTextView.")
        return try XCTUnwrap(editors.first)
    }

    private func descendantScrollViews(in view: NSView) -> [NSScrollView] {
        var matches = (view as? NSScrollView).map { [$0] } ?? []
        for child in view.subviews {
            matches.append(contentsOf: descendantScrollViews(in: child))
        }
        return matches
    }

    private func frame<Content: View>(
        named identifier: String,
        in host: NSHostingView<Content>
    ) throws -> NSRect {
        let matches = markers(named: identifier, in: host)
        XCTAssertEqual(matches.count, 1, "Expected one runtime marker named \(identifier)")
        let marker = try XCTUnwrap(matches.first)
        return marker.convert(marker.bounds, to: host)
    }

    private func scrollView<Content: View>(
        named identifier: String,
        in host: NSHostingView<Content>
    ) throws -> NSScrollView {
        let matches = markers(named: identifier, in: host)
        XCTAssertEqual(matches.count, 1, "Expected one tagged viewport named \(identifier)")
        return try XCTUnwrap(matches.first as? NSScrollView)
    }

    private func scrollToPractice<Content: View>(
        in host: NSHostingView<Content>
    ) throws {
        let scrollView = try scrollView(named: "lesson-document-scroll", in: host)
        for _ in 0..<5 where markers(named: "practice-workspace", in: host).isEmpty {
            let maximumOffset = max(
                0,
                (scrollView.documentView?.bounds.height ?? 0)
                    - scrollView.contentView.bounds.height
            )
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: maximumOffset))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            refresh(host)
        }
    }

    private func documentFrame<Content: View>(
        named identifier: String,
        in host: NSHostingView<Content>,
        scrollView: NSScrollView
    ) throws -> NSRect {
        let marker = try XCTUnwrap(markers(named: identifier, in: host).first)
        let documentView = try XCTUnwrap(scrollView.documentView)
        return marker.convert(marker.bounds, to: documentView)
    }

    private func isMeaningfullyVisible(
        _ marker: NSView,
        in scrollView: NSScrollView
    ) -> Bool {
        guard let documentView = scrollView.documentView else { return false }
        let markerFrame = marker.convert(marker.bounds, to: documentView)
        let visible = scrollView.documentVisibleRect
        return visible.minY <= markerFrame.midY && markerFrame.midY <= visible.maxY
    }

    private func visibilityDiagnostics(_ marker: NSView, in scrollView: NSScrollView) -> String {
        guard let documentView = scrollView.documentView else { return "missing document" }
        let markerFrame = marker.convert(marker.bounds, to: documentView)
        return "row=\(markerFrame), visible=\(scrollView.documentVisibleRect), clipOrigin=\(scrollView.contentView.bounds.origin), clipFrame=\(scrollView.contentView.frame), documentBounds=\(documentView.bounds), documentFrame=\(documentView.frame), contentInsets=\(scrollView.contentInsets), scrollerInsets=\(scrollView.scrollerInsets)"
    }

    private func intersectsTopFourPoints(
        _ marker: NSView,
        in scrollView: NSScrollView
    ) -> Bool {
        guard let documentView = scrollView.documentView else { return false }
        let visible = scrollView.documentVisibleRect
        let topStrip: NSRect
        if documentView.isFlipped {
            topStrip = NSRect(x: visible.minX, y: visible.minY, width: visible.width, height: 4)
        } else {
            topStrip = NSRect(x: visible.minX, y: visible.maxY - 4, width: visible.width, height: 4)
        }
        let markerFrame = marker.convert(marker.bounds, to: documentView)
        return markerFrame.intersects(topStrip)
    }

    private func assertFiniteAndInside(
        _ frame: NSRect,
        rootBounds: NSRect,
        context: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(frame.minX.isFinite, context, file: file, line: line)
        XCTAssertTrue(frame.minY.isFinite, context, file: file, line: line)
        XCTAssertTrue(frame.width.isFinite, context, file: file, line: line)
        XCTAssertTrue(frame.height.isFinite, context, file: file, line: line)
        XCTAssertTrue(
            rootBounds.insetBy(dx: -1, dy: -1).contains(frame),
            "Frame \(frame) escapes root \(rootBounds). \(context)",
            file: file,
            line: line
        )
    }
}

@MainActor
private final class CourseWorkspaceFixture {
    let root: URL
    let settings: AppSettings
    let lessonIDs: [Int]
    private let lessons: LessonStore
    private let progress: ProgressStore
    private let registry: CourseContentRegistry

    convenience init(lessons sourceLessons: [Lesson] = Curriculum.defaultLessons) throws {
        try self.init(lessonData: JSONEncoder().encode(sourceLessons))
    }

    init(lessonData: Data) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CourseWorkspaceLayoutTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let lessonURL = root.appendingPathComponent("lessons.json")
        try lessonData.write(to: lessonURL)
        let decodedLessons = try JSONDecoder().decode([Lesson].self, from: lessonData)
        lessons = LessonStore(fileURL: lessonURL, defaults: decodedLessons)
        lessonIDs = lessons.lessons.map(\.id)
        progress = ProgressStore(
            fileURL: root.appendingPathComponent("progress.json"),
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )
        let suite = "CourseWorkspaceLayoutTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        settings = AppSettings(userDefaults: defaults)
        settings.hasSeenWelcome = true
        registry = CourseContentRegistry(
            providers: [.swiftDevelopment: LegacySwiftCourseProvider(store: lessons)]
        )
    }

    func makeModel(
        runCode: ((String) async -> RunResult)? = nil
    ) -> AppModel {
        AppModel(
            store: lessons,
            progress: progress,
            settings: settings,
            contentRegistry: registry,
            runCode: runCode
        )
    }

    func seedPresentationState(_ state: LessonPresentationState, for key: LessonKey) {
        progress.setPresentationState(state, for: key)
    }

    func recordRecallAnswer(lessonKey: LessonKey, questionID: String, wasCorrect: Bool) {
        progress.recordRecallAnswer(
            lessonKey: lessonKey,
            questionID: questionID,
            wasCorrect: wasCorrect
        )
    }

    func recallAnswerCount(lessonKey: LessonKey, questionID: String) -> Int {
        progress.progress(for: lessonKey.courseID).stageEvents.filter {
            $0.lessonLocalID == lessonKey.localID
                && $0.kind == .recallAnswered
                && $0.questionID == questionID
        }.count
    }

    func recallAnswer(lessonKey: LessonKey, questionID: String) -> Bool? {
        progress.recallAnswer(for: lessonKey, questionID: questionID)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }
}
