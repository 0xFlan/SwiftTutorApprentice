import AppKit
import SwiftUI
import XCTest
@testable import SwiftTutorApprentice

final class AICodeReviewViewLayoutTests: XCTestCase {
    // SwiftUI's asynchronous accessibility bridge can retain elements after this
    // test returns. Keep these tiny animation-free hosted windows alive for the
    // XCTest process so later AppKit tests cannot dereference released UI parents.
    @MainActor private static var retainedHostedWindows: [NSWindow] = []

    @MainActor
    func testLongestPilotExerciseStaysFiniteAndBoundedAt680Points() {
        let host = NSHostingView(
            rootView: AICodeReviewView(exercise: Self.longestPilotExercise) { _ in }
                .frame(width: 680)
        )
        let fittingSize = host.fittingSize

        XCTAssertTrue(fittingSize.width.isFinite)
        XCTAssertTrue(fittingSize.height.isFinite)
        XCTAssertGreaterThan(fittingSize.width, 0)
        XCTAssertGreaterThan(fittingSize.height, 0)
        XCTAssertLessThanOrEqual(fittingSize.width, 680)
        XCTAssertLessThanOrEqual(
            fittingSize.height,
            720,
            "Scrollable code and claim regions must not grow without bound."
        )
    }

    @MainActor
    func testHostedWindowsDisableTransformAnimations() {
        let rendered = hostInWindow(Text("Animation-free host"), width: 320, height: 120)
        defer { retainWindow(rendered.window) }

        XCTAssertEqual(rendered.window.animationBehavior, .none)
    }

    @MainActor
    func testAccessibilityAndSubmissionSemantics() throws {
        let baseline = hostInWindow(
            Button("Accessibility baseline") {}
                .accessibilityLabel("Accessibility baseline control"),
            width: 240,
            height: 80
        )
        let baselineStrings = accessibilityStrings(
            in: accessibilityElements(in: baseline.host)
        )
        retainWindow(baseline.window)
        try XCTSkipIf(
            baselineStrings.isEmpty,
            "The known-good SwiftUI Button exposes no NSAccessibility output in this XCTest process, so hosted SwiftUI accessibility is unsupported here."
        )

        var submissions: [AICodeReviewEvaluation] = []
        let rendered = hostInWindow(
            AICodeReviewView(exercise: Self.longExercise) {
                submissions.append($0)
            },
            width: 680,
            height: 760
        )
        defer { retainWindow(rendered.window) }

        var elements = accessibilityElements(in: rendered.host)
        XCTAssertFalse(
            elements.isEmpty,
            "The baseline SwiftUI control exposed NSAccessibility output, but the AI review exposed none."
        )

        let initialStrings = accessibilityStrings(in: elements).joined(separator: " | ")
        for required in [
            "Generated code",
            Self.longExercise.generatedCode,
            "Claim 1: The generated function returns the doubled input.",
            "Claim 1 True",
            "Claim 1 False",
            "Claim 2: The input is changed in place.",
            "Claim 2 True",
            "Claim 2 False",
            "No answer selected",
            "Submit AI code review"
        ] {
            XCTAssertTrue(
                initialStrings.contains(required),
                "Missing rendered accessibility content: \(required)\n\(initialStrings)"
            )
        }
        XCTAssertFalse(initialStrings.contains(Self.longExercise.claims[0].explanation))
        XCTAssertFalse(initialStrings.contains(Self.longExercise.claims[1].explanation))
        XCTAssertFalse(initialStrings.contains("Verify code; do not trust generation blindly"))

        let codeElements = elements.filter { $0.accessibilityLabel() == "Generated code" }
        XCTAssertEqual(codeElements.count, 1)
        XCTAssertEqual(codeElements.first?.accessibilityValue() as? String, Self.longExercise.generatedCode)
        XCTAssertEqual(codeElements.first?.accessibilityRole(), .staticText)
        XCTAssertFalse(codeElements.first?.accessibilityPerformPress() ?? true)

        var submit = try XCTUnwrap(element(labeled: "Submit AI code review", in: elements))
        XCTAssertFalse(submit.isAccessibilityEnabled())
        XCTAssertNotEqual(
            (rendered.window.accessibilityDefaultButton() as? NSAccessibilityProtocol)?
                .accessibilityLabel(),
            "Submit AI code review"
        )
        XCTAssertTrue(submissions.isEmpty)

        try press("Claim 1 True", in: rendered)
        elements = accessibilityElements(in: rendered.host)
        XCTAssertTrue(accessibilityStrings(in: elements).contains("Selected answer: True"))
        submit = try XCTUnwrap(element(labeled: "Submit AI code review", in: elements))
        XCTAssertFalse(submit.isAccessibilityEnabled())

        try press("Claim 2 False", in: rendered)
        elements = accessibilityElements(in: rendered.host)
        XCTAssertTrue(accessibilityStrings(in: elements).contains("Selected answer: False"))
        submit = try XCTUnwrap(element(labeled: "Submit AI code review", in: elements))
        XCTAssertTrue(submit.isAccessibilityEnabled())
        XCTAssertEqual(
            (rendered.window.accessibilityDefaultButton() as? NSAccessibilityProtocol)?
                .accessibilityLabel(),
            "Submit AI code review"
        )

        XCTAssertTrue(submit.accessibilityPerformPress())
        refresh(rendered.host)
        XCTAssertEqual(submissions.count, 1)
        guard case .complete(_, let correctCount, let totalCount, let passed) = submissions[0] else {
            return XCTFail("Submit must emit one complete evaluation.")
        }
        XCTAssertEqual(correctCount, 2)
        XCTAssertEqual(totalCount, 2)
        XCTAssertTrue(passed)

        elements = accessibilityElements(in: rendered.host)
        let submittedStrings = accessibilityStrings(in: elements).joined(separator: " | ")
        XCTAssertTrue(submittedStrings.contains(Self.longExercise.claims[0].explanation))
        XCTAssertTrue(submittedStrings.contains(Self.longExercise.claims[1].explanation))
        XCTAssertTrue(submittedStrings.contains("2 of 2 correct"))
        XCTAssertTrue(submittedStrings.contains("Verify code; do not trust generation blindly"))
        XCTAssertNotNil(element(labeled: "Retry AI code review", in: elements))

        submit = try XCTUnwrap(element(labeled: "Submit AI code review", in: elements))
        XCTAssertTrue(submit.accessibilityPerformPress())
        refresh(rendered.host)
        XCTAssertEqual(submissions.count, 2, "Each Submit action must invoke the callback exactly once.")

        try press("Retry AI code review", in: rendered)
        elements = accessibilityElements(in: rendered.host)
        let retriedStrings = accessibilityStrings(in: elements).joined(separator: " | ")
        XCTAssertEqual(submissions.count, 2)
        XCTAssertFalse(retriedStrings.contains(Self.longExercise.claims[0].explanation))
        XCTAssertFalse(retriedStrings.contains(Self.longExercise.claims[1].explanation))
        XCTAssertTrue(retriedStrings.contains("No answer selected"))
        submit = try XCTUnwrap(element(labeled: "Submit AI code review", in: elements))
        XCTAssertFalse(submit.isAccessibilityEnabled())
    }

    @MainActor
    func testSubmissionRuntimeWithoutAccessibilitySupport() {
        var submissions: [AICodeReviewEvaluation] = []
        let session = AICodeReviewSession(exercise: Self.longExercise)
        func submit() {
            guard let evaluation = session.submit() else { return }
            submissions.append(evaluation)
        }

        XCTAssertEqual(session.submitMode, .disabled)
        XCTAssertNil(session.submittedEvaluation)
        submit()
        XCTAssertTrue(submissions.isEmpty)
        XCTAssertNil(session.submittedEvaluation)

        session.select(true, for: "claim-return")
        XCTAssertEqual(session.submitMode, .disabled)
        XCTAssertNil(session.submittedEvaluation)
        submit()
        XCTAssertTrue(submissions.isEmpty)

        session.select(false, for: "claim-mutation")
        XCTAssertEqual(session.submitMode, .enabledDefault)
        XCTAssertNil(session.submittedEvaluation)

        submit()
        XCTAssertEqual(submissions.count, 1)
        XCTAssertEqual(session.submittedEvaluation, submissions[0])
        guard case .complete(let feedback, let correctCount, let totalCount, let passed) =
            session.submittedEvaluation else {
            return XCTFail("A complete Submit must expose feedback.")
        }
        XCTAssertEqual(feedback.count, 2)
        XCTAssertEqual(correctCount, 2)
        XCTAssertEqual(totalCount, 2)
        XCTAssertTrue(passed)

        submit()
        XCTAssertEqual(
            submissions.count,
            2,
            "Each complete Submit action must call the production callback exactly once."
        )

        session.retry()
        XCTAssertTrue(session.answers.isEmpty)
        XCTAssertNil(session.submittedEvaluation)
        XCTAssertEqual(session.submitMode, .disabled)
        XCTAssertEqual(submissions.count, 2)
    }

    @MainActor
    func testHostedReplacementResetsStateAndUsesOnlyCurrentCallback() throws {
        let oldCallbackCount = CallbackCount()
        let newCallbackCount = CallbackCount()
        let model = ReplacementParentModel(
            exercise: Self.longExercise,
            onSubmit: { _ in oldCallbackCount.value += 1 }
        )
        var presentedSessions: [AICodeReviewSession] = []
        var presentedSubmitActions: [() -> Void] = []
        let rendered = hostInWindow(
            ReplacementParent(
                model: model,
                onSessionPresented: { session, submit in
                    presentedSessions.append(session)
                    presentedSubmitActions.append(submit)
                }
            ),
            width: 680,
            height: 760
        )
        defer { retainWindow(rendered.window) }
        waitUntil { presentedSessions.count == 1 }

        let oldSession = try XCTUnwrap(presentedSessions.first)
        oldSession.select(true, for: "claim-return")
        oldSession.select(false, for: "claim-mutation")
        XCTAssertNotNil(oldSession.submit())
        XCTAssertFalse(oldSession.answers.isEmpty)
        XCTAssertNotNil(oldSession.submittedEvaluation)
        XCTAssertEqual(oldCallbackCount.value, 0)

        model.replace(
            exercise: Self.replacementExercise,
            onSubmit: { _ in newCallbackCount.value += 1 }
        )
        refresh(rendered.host)
        waitUntil { presentedSessions.count == 2 }
        guard presentedSessions.count == 2,
              presentedSubmitActions.count == 2 else { return }

        let newSession = presentedSessions[1]
        XCTAssertFalse(oldSession === newSession)
        XCTAssertEqual(newSession.exercise.id, Self.replacementExercise.id)
        XCTAssertEqual(newSession.exercise.prompt, Self.replacementExercise.prompt)
        XCTAssertTrue(newSession.answers.isEmpty)
        XCTAssertNil(newSession.submittedEvaluation)
        XCTAssertEqual(oldCallbackCount.value, 0)
        XCTAssertEqual(newCallbackCount.value, 0)

        newSession.select(true, for: "replacement-claim")
        presentedSubmitActions[1]()
        XCTAssertEqual(oldCallbackCount.value, 0)
        XCTAssertEqual(newCallbackCount.value, 1)
        XCTAssertNotNil(newSession.submittedEvaluation)
    }

    @MainActor
    private func hostInWindow<Content: View>(
        _ content: Content,
        width: CGFloat,
        height: CGFloat
    ) -> (host: NSHostingView<Content>, window: NSWindow) {
        let host = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.animationBehavior = .none
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        window.contentView = container
        window.setContentSize(NSSize(width: width, height: height))
        window.orderFrontRegardless()
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        refresh(host)
        return (host, window)
    }

    @MainActor
    private func retainWindow(_ window: NSWindow) {
        window.animationBehavior = .none
        window.orderOut(nil)
        Self.retainedHostedWindows.append(window)
    }

    @MainActor
    private func press<Content: View>(
        _ label: String,
        in rendered: (host: NSHostingView<Content>, window: NSWindow)
    ) throws {
        let target = try XCTUnwrap(
            element(labeled: label, in: accessibilityElements(in: rendered.host)),
            "Missing accessibility control \(label)."
        )
        XCTAssertTrue(target.isAccessibilityEnabled())
        XCTAssertTrue(target.accessibilityPerformPress())
        refresh(rendered.host)
    }

    @MainActor
    private func refresh(_ view: NSView) {
        view.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 1,
        _ condition: () -> Bool
    ) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        XCTAssertTrue(condition(), "Timed out waiting for the hosted view to update.")
    }

    private func element(
        labeled label: String,
        in elements: [NSAccessibilityProtocol]
    ) -> NSAccessibilityProtocol? {
        elements.first { $0.accessibilityLabel() == label }
    }

    private func accessibilityElements(in element: Any) -> [NSAccessibilityProtocol] {
        guard let accessible = element as? NSAccessibilityProtocol else { return [] }
        var elements = [accessible]
        let children = accessible.accessibilityChildren()
            ?? accessible.accessibilityChildrenInNavigationOrder()
            ?? []
        for child in NSAccessibility.unignoredChildren(from: children) {
            elements.append(contentsOf: accessibilityElements(in: child))
        }
        return elements
    }

    private func accessibilityStrings(in elements: [NSAccessibilityProtocol]) -> [String] {
        elements.flatMap { element in
            [
                element.accessibilityLabel(),
                element.accessibilityValue() as? String,
                element.accessibilityHelp()
            ].compactMap { $0 }
        }
    }

    private static let longestPilotExercise: AICodeReviewExercise = {
        func contentLength(_ exercise: AICodeReviewExercise) -> Int {
            exercise.generatedCode.count
                + (exercise.claims.map(\.explanation.count).max() ?? 0)
        }
        let candidates = [
            SwiftPilotPresentationContent.lesson1.aiCodeExercise,
            SwiftPilotPresentationContent.lesson2.aiCodeExercise,
            SwiftPilotPresentationContent.lesson3.aiCodeExercise
        ].compactMap { $0 }
        guard let longest = candidates.max(by: { contentLength($0) < contentLength($1) }) else {
            preconditionFailure("The Swift pilot must include an AI code review exercise.")
        }
        return longest
    }()

    private static let longExercise = AICodeReviewExercise(
        id: "long-review",
        prompt: "Review every claim about this generated function before trusting it.",
        generatedCode: """
        func doubled(_ input: Int) -> Int {
            let result = input * 2
            return result
        }

        print(doubled(21))
        """,
        claims: [
            AICodeClaim(
                id: "claim-return",
                text: "The generated function returns the doubled input.",
                isCorrect: true,
                explanation: "The multiplication result is stored locally and returned without changing the caller's input, even when this explanation wraps across several lines at the supported lesson width."
            ),
            AICodeClaim(
                id: "claim-mutation",
                text: "The input is changed in place.",
                isCorrect: false,
                explanation: "The input parameter is immutable here; the function creates a separate result constant and leaves the original argument unchanged."
            )
        ],
        conceptIDs: []
    )

    private static let replacementExercise = AICodeReviewExercise(
        id: "long-review",
        prompt: "Replacement exercise prompt rendered in the same parent position.",
        generatedCode: "let replacement = true",
        claims: [
            AICodeClaim(
                id: "replacement-claim",
                text: "The replacement constant stores true.",
                isCorrect: true,
                explanation: "The Boolean literal true is assigned to replacement."
            )
        ],
        conceptIDs: []
    )
}

@MainActor
private final class ReplacementParentModel: ObservableObject {
    @Published private(set) var exercise: AICodeReviewExercise
    private(set) var onSubmit: (AICodeReviewEvaluation) -> Void

    init(
        exercise: AICodeReviewExercise,
        onSubmit: @escaping (AICodeReviewEvaluation) -> Void
    ) {
        self.exercise = exercise
        self.onSubmit = onSubmit
    }

    func replace(
        exercise: AICodeReviewExercise,
        onSubmit: @escaping (AICodeReviewEvaluation) -> Void
    ) {
        self.onSubmit = onSubmit
        self.exercise = exercise
    }
}

private struct ReplacementParent: View {
    @ObservedObject var model: ReplacementParentModel
    let onSessionPresented: (AICodeReviewSession, @escaping () -> Void) -> Void

    var body: some View {
        AICodeReviewView(
            exercise: model.exercise,
            onSubmit: model.onSubmit,
            onSessionPresented: onSessionPresented
        )
    }
}

private final class CallbackCount {
    var value = 0
}
