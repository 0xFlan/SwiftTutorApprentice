import Foundation
import XCTest
@testable import SwiftTutorApprentice

final class CourseContentRegistryTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CourseContentRegistryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
    }

    func testSwiftProviderReturnsExplicitKeysForLegacyLessons() throws {
        let provider = makeSwiftProvider()

        XCTAssertEqual(provider.modules.map(\.id.rawValue), ["swift-current"])
        let module = try XCTUnwrap(provider.modules.first)
        XCTAssertEqual(
            provider.lessons(in: module.id).map(\.key),
            [.swift(1), .swift(2), .swift(3)]
        )
        XCTAssertEqual(provider.lesson(for: .swift(2))?.lesson.id, 2)
    }

    func testRegistryDistinguishesComingNextFromMissingAvailableContent() {
        let registry = CourseContentRegistry(providers: [:])

        XCTAssertThrowsError(try registry.provider(for: .webDevelopment)) { error in
            XCTAssertEqual(error as? CourseContentError, .comingNext(.webDevelopment))
        }
        XCTAssertThrowsError(try registry.provider(for: .swiftDevelopment)) { error in
            XCTAssertEqual(error as? CourseContentError, .contentUnavailable(.swiftDevelopment))
        }
    }

    func testRegistryTreatsMismatchedProviderRegistrationAsUnavailable() {
        let networkingProvider = TestCourseContentProvider(courseID: .networking)
        let registry = CourseContentRegistry(
            providers: [.swiftDevelopment: networkingProvider]
        )

        XCTAssertThrowsError(try registry.provider(for: .swiftDevelopment)) { error in
            XCTAssertEqual(error as? CourseContentError, .contentUnavailable(.swiftDevelopment))
        }
    }

    func testProviderRejectsKeysFromAnotherCourse() {
        let provider = makeSwiftProvider()
        let networkingKey = LessonKey(
            courseID: .networking,
            localID: LessonLocalID(rawValue: "1")
        )

        XCTAssertNil(provider.lesson(for: networkingKey))
    }

    private func makeSwiftProvider() -> LegacySwiftCourseProvider {
        let url = temporaryDirectory.appendingPathComponent("lessons.json")
        let store = LessonStore(
            fileURL: url,
            defaults: Array(Curriculum.defaultLessons.prefix(3))
        )
        return LegacySwiftCourseProvider(store: store)
    }
}

private struct TestCourseContentProvider: CourseContentProvider {
    let courseID: CourseID
    let modules: [CourseModule] = []

    func lessons(in moduleID: ModuleID) -> [CourseLesson] { [] }
    func lesson(for key: LessonKey) -> CourseLesson? { nil }
    func contains(_ key: LessonKey) -> Bool { false }
}
