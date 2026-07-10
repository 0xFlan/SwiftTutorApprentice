import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

final class LessonStageStepperLayoutTests: XCTestCase {
    @MainActor
    func testStageStepperKeepsCompactHeightUnderNarrowProposal() {
        let stepper = LessonStageStepper(
            deepLessonComplete: true,
            modifyComplete: false,
            practiceComplete: true,
            onOpenDeepLesson: {},
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
}
