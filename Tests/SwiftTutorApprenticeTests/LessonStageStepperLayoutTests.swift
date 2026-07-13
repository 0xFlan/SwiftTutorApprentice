import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

final class LessonStageStepperLayoutTests: XCTestCase {
    func testStageStepperUsesTheFourNonLockingLearningStagesInOrder() {
        XCTAssertEqual(
            LessonStageStepper.orderedStageTitles,
            ["Watch", "Recall", "Modify", "Practice/Run"]
        )
    }

    @MainActor
    func testStageStepperKeepsCompactHeightUnderNarrowProposal() {
        let stepper = LessonStageStepper(
            watchStatus: "Complete",
            recallStatus: "Answered",
            modifyComplete: false,
            practiceComplete: true,
            onOpenWatch: {},
            onOpenRecall: {},
            onOpenModify: {}
        )
        .frame(width: 360)

        let hostingView = NSHostingView(rootView: stepper)

        XCTAssertLessThanOrEqual(
            hostingView.fittingSize.height,
            100,
            "The stage strip must stay compact so it cannot enlarge the NavigationSplitView beyond the window."
        )
    }

    @MainActor
    func testUnavailableRecallAndModifyPublishTruthfulNonActionableStatuses() {
        let host = host(
            LessonStageStepper(
                watchStatus: "Unavailable",
                recallStatus: "Not answered",
                modifyComplete: false,
                practiceComplete: false,
                onOpenWatch: {},
                onOpenRecall: {},
                onOpenModify: {},
                watchEnabled: false,
                recallEnabled: false,
                modifyEnabled: false
            )
        )

        XCTAssertEqual(markers(named: "lesson-stage-recall-unavailable", in: host).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-unavailable", in: host).count, 1)
        XCTAssertTrue(markers(named: "lesson-stage-recall-not-answered", in: host).isEmpty)
        XCTAssertTrue(markers(named: "lesson-stage-modify-not-passed", in: host).isEmpty)
        XCTAssertTrue(markers(named: "lesson-stage-recall-enabled", in: host).isEmpty)
        XCTAssertTrue(markers(named: "lesson-stage-modify-enabled", in: host).isEmpty)
    }

    @MainActor
    func testAvailableRecallAndModifyKeepPendingAndPassedStatuses() {
        let pending = host(
            LessonStageStepper(
                watchStatus: "Not started",
                recallStatus: "Not answered",
                modifyComplete: false,
                practiceComplete: false,
                onOpenWatch: {},
                onOpenRecall: {},
                onOpenModify: {}
            )
        )
        XCTAssertEqual(markers(named: "lesson-stage-recall-not-answered", in: pending).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-not-passed", in: pending).count, 1)

        let passed = host(
            LessonStageStepper(
                watchStatus: "Complete",
                recallStatus: "Answered",
                modifyComplete: true,
                practiceComplete: true,
                onOpenWatch: {},
                onOpenRecall: {},
                onOpenModify: {}
            )
        )
        XCTAssertEqual(markers(named: "lesson-stage-recall-answered", in: passed).count, 1)
        XCTAssertEqual(markers(named: "lesson-stage-modify-passed", in: passed).count, 1)
    }

    @MainActor
    private func host<Content: View>(_ content: Content) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: AnyView(content.frame(width: 680)))
        host.frame = NSRect(x: 0, y: 0, width: 680, height: 100)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.03))
        return host
    }

    private func markers(named identifier: String, in view: NSView) -> [NSView] {
        var matches = view.identifier?.rawValue == identifier ? [view] : []
        for child in view.subviews {
            matches.append(contentsOf: markers(named: identifier, in: child))
        }
        return matches
    }
}
