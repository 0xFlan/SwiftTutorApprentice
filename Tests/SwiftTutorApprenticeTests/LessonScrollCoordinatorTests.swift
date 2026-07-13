import XCTest
@testable import SwiftTutorApprentice

@MainActor
final class LessonScrollCoordinatorTests: XCTestCase {
    func testCourseEntryAndProgrammaticSelectionsRequestSidebarVisibilityOnce() {
        let coordinator = LessonScrollCoordinator()

        coordinator.select(.swift(1), origin: .courseEntry)
        let courseEntryRequest = coordinator.sidebarVisibilityRequest
        XCTAssertEqual(courseEntryRequest?.lessonKey, .swift(1))
        XCTAssertEqual(courseEntryRequest?.alignment, .center)

        coordinator.select(.swift(2), origin: .programmatic)
        let programmaticRequest = coordinator.sidebarVisibilityRequest
        XCTAssertEqual(programmaticRequest?.lessonKey, .swift(2))
        XCTAssertEqual(programmaticRequest?.alignment, .center)
        XCTAssertGreaterThan(
            programmaticRequest?.id ?? 0,
            courseEntryRequest?.id ?? .max
        )
    }

    func testDirectSelectionRequestsNearestSidebarVisibility() {
        let coordinator = LessonScrollCoordinator()

        coordinator.select(.swift(1), origin: .direct)

        XCTAssertEqual(coordinator.sidebarVisibilityRequest?.lessonKey, .swift(1))
        XCTAssertEqual(coordinator.sidebarVisibilityRequest?.alignment, .nearest)
        XCTAssertEqual(coordinator.detailTopGeneration, 1)
    }

    func testChangingLessonEmitsExactlyOneDetailGenerationAndReselectEmitsNothing() {
        let coordinator = LessonScrollCoordinator()

        coordinator.select(.swift(1), origin: .courseEntry)
        let firstSidebarRequest = coordinator.sidebarVisibilityRequest
        XCTAssertEqual(coordinator.detailTopGeneration, 1)

        coordinator.select(.swift(1), origin: .programmatic)
        XCTAssertEqual(coordinator.detailTopGeneration, 1)
        XCTAssertEqual(coordinator.sidebarVisibilityRequest, firstSidebarRequest)

        coordinator.select(.swift(2), origin: .direct)
        XCTAssertEqual(coordinator.detailTopGeneration, 2)
        XCTAssertEqual(coordinator.sidebarVisibilityRequest?.lessonKey, .swift(2))
        XCTAssertEqual(coordinator.sidebarVisibilityRequest?.alignment, .nearest)
    }

    func testSidebarVisibilityRequestCanOnlyBeConsumedOnce() {
        let coordinator = LessonScrollCoordinator()
        coordinator.select(.swift(3), origin: .programmatic)
        let request = coordinator.sidebarVisibilityRequest

        XCTAssertTrue(coordinator.consumeSidebarVisibilityRequest(id: request?.id))
        XCTAssertNil(coordinator.sidebarVisibilityRequest)
        XCTAssertFalse(coordinator.consumeSidebarVisibilityRequest(id: request?.id))
    }

    func testSupersededRequestCannotBeFulfilledAfterDirectSelection() throws {
        let coordinator = LessonScrollCoordinator()
        coordinator.select(.swift(24), origin: .programmatic)
        let staleRequest = try XCTUnwrap(coordinator.sidebarVisibilityRequest)

        coordinator.select(.swift(1), origin: .direct)
        let directRequest = try XCTUnwrap(coordinator.sidebarVisibilityRequest)

        XCTAssertFalse(
            coordinator.fulfillSidebarVisibilityRequest(staleRequest),
            "A stale yielded task must not scroll after a newer direct selection."
        )
        XCTAssertEqual(coordinator.sidebarVisibilityRequest, directRequest)
        XCTAssertEqual(directRequest.alignment, .nearest)
        XCTAssertTrue(coordinator.fulfillSidebarVisibilityRequest(directRequest))
        XCTAssertNil(coordinator.sidebarVisibilityRequest)
        XCTAssertEqual(coordinator.detailTopGeneration, 2)

        coordinator.select(.swift(13), origin: .programmatic)
        let supersededRequest = try XCTUnwrap(coordinator.sidebarVisibilityRequest)
        coordinator.select(.swift(24), origin: .programmatic)
        let currentRequest = try XCTUnwrap(coordinator.sidebarVisibilityRequest)

        XCTAssertFalse(coordinator.fulfillSidebarVisibilityRequest(supersededRequest))
        XCTAssertTrue(coordinator.fulfillSidebarVisibilityRequest(currentRequest))
    }
}
