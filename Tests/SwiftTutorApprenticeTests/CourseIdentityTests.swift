import XCTest
@testable import SwiftTutorApprentice

final class CourseIdentityTests: XCTestCase {
    func testSwiftIntegerLessonIDBridgesWithoutRenumbering() {
        let key = LessonKey.swift(24)

        XCTAssertEqual(key.courseID, .swiftDevelopment)
        XCTAssertEqual(key.localID.rawValue, "24")
        XCTAssertEqual(key.id, "swift-development:24")
    }

    func testObjectiveSetIDIsAvailableToCourseDefinitions() {
        let objectiveSetID = ObjectiveSetID(rawValue: "certiport-swift-associate-2024")

        XCTAssertEqual(objectiveSetID.rawValue, "certiport-swift-associate-2024")
    }
}
